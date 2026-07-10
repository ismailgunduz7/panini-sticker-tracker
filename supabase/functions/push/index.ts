// Sends APNs push notifications for friend-related events. Called by the
// database (pg_net) from the friend RPCs with a shared-secret header. Looks up
// the target user's device tokens with the service role and delivers a
// localized alert; each device renders the text in its own language via the
// loc-keys, which resolve against the app bundle's Localizable strings.
//
// Deploy: supabase functions deploy push --no-verify-jwt
// Required secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_HOST,
//   APNS_PRIVATE_KEY (.p8 contents), PUSH_FUNCTION_SECRET.
//   APNS_HOST = api.sandbox.push.apple.com (dev) | api.push.apple.com (prod).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;
const APNS_HOST = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const PUSH_FUNCTION_SECRET = Deno.env.get("PUSH_FUNCTION_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// kind -> localized title/body key pair (resolved on-device against the app's
// Localizable strings). The body key takes the actor username as loc-arg.
const LOC: Record<string, { title: string; body: string }> = {
  friend_request: { title: "notif_friend_request_title", body: "notif_friend_request_body" },
  friend_accept: { title: "notif_friend_accept_title", body: "notif_friend_accept_body" },
  new_trade: { title: "notif_new_trade_title", body: "notif_new_trade_body" },
};

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

let cachedKey: CryptoKey | null = null;
async function signingKey(): Promise<CryptoKey> {
  if (!cachedKey) {
    cachedKey = await crypto.subtle.importKey(
      "pkcs8",
      pemToDer(APNS_PRIVATE_KEY),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  }
  return cachedKey;
}

// APNs provider token (JWT). Valid up to 1h; refresh well inside that.
let cachedJwt: { token: string; iat: number } | null = null;
async function providerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.iat < 3000) return cachedJwt.token;
  const enc = new TextEncoder();
  const header = base64url(enc.encode(JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID })));
  const payload = base64url(enc.encode(JSON.stringify({ iss: APNS_TEAM_ID, iat: now })));
  const signingInput = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    await signingKey(),
    enc.encode(signingInput),
  );
  const token = `${signingInput}.${base64url(new Uint8Array(signature))}`;
  cachedJwt = { token, iat: now };
  return token;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-push-secret") !== PUSH_FUNCTION_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }

  const { user_id, kind, actor } = await req.json().catch(() => ({}));
  const loc = LOC[kind];
  if (!user_id || !loc) return new Response("bad request", { status: 400 });

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", user_id);
  if (!tokens || tokens.length === 0) return new Response("no tokens", { status: 200 });

  const jwt = await providerToken();
  const body = JSON.stringify({
    aps: {
      alert: { "title-loc-key": loc.title, "loc-key": loc.body, "loc-args": [actor ?? ""] },
      sound: "default",
    },
    kind,
  });

  const stale: string[] = [];
  await Promise.all(
    tokens.map(async ({ token }) => {
      const res = await fetch(`https://${APNS_HOST}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": APNS_BUNDLE_ID,
          "apns-push-type": "alert",
        },
        body,
      });
      // 410 Gone or 400 BadDeviceToken => the token is dead; prune it.
      if (res.status === 410) {
        stale.push(token);
      } else if (res.status === 400) {
        const reason = await res.json().catch(() => ({}));
        if (reason?.reason === "BadDeviceToken") stale.push(token);
      }
    }),
  );

  if (stale.length > 0) {
    await supabase.from("device_tokens").delete().in("token", stale);
  }

  return new Response("ok", { status: 200 });
});
