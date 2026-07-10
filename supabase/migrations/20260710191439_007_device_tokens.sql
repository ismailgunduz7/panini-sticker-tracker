-- APNs device tokens for push notifications. One row per device token; the
-- token is the primary key so a device that switches accounts simply reassigns
-- its row to the new user. The FK to profiles cascades on delete, so
-- delete_account already cleans these up. Clients never read others' tokens
-- and never write directly — all writes go through the definer RPCs below, and
-- the sender (an Edge Function) reads with the service role, bypassing RLS.

create table public.device_tokens (
    token text primary key,
    user_id uuid not null references public.profiles (id) on delete cascade,
    platform text not null default 'ios',
    updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy "own device tokens"
    on public.device_tokens for select
    using (auth.uid() = user_id);

-- Registers (or reassigns) the caller's device token.
create function public.register_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    insert into public.device_tokens (token, user_id, platform, updated_at)
    values (p_token, auth.uid(), 'ios', now())
    on conflict (token) do update
        set user_id = auth.uid(), updated_at = now();
end;
$$;

-- Removes the caller's device token (on sign-out).
create function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.device_tokens
    where token = p_token and user_id = auth.uid();
end;
$$;

-- Read-only for clients (own rows); all writes go through the definer RPCs.
grant select on public.device_tokens to authenticated;

revoke execute on function public.register_device_token from anon, public;
revoke execute on function public.unregister_device_token from anon, public;
grant execute on function public.register_device_token to authenticated;
grant execute on function public.unregister_device_token to authenticated;
