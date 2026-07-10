-- Push notifications for friend requests and acceptances. The two friend RPCs
-- already know exactly who to notify, so they call notify_user, which posts to
-- the `push` Edge Function via pg_net. Delivery is fire-and-forget: pg_net is
-- async, so a push failure can never block or fail the friend action itself.
-- The function URL and shared secret live in Vault (push_function_url /
-- push_function_secret); if either is missing, notify_user silently no-ops.

create extension if not exists pg_net;

create or replace function public.notify_user(p_user uuid, p_kind text, p_actor text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_url text;
    v_secret text;
begin
    select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_function_url';
    select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_function_secret';

    -- Push not configured yet: skip quietly rather than error.
    if v_url is null or v_secret is null then
        return;
    end if;

    perform net.http_post(
        url := v_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-push-secret', v_secret
        ),
        body := jsonb_build_object(
            'user_id', p_user,
            'kind', p_kind,
            'actor', p_actor
        )
    );
end;
$$;

-- Re-declare the two RPCs (unchanged logic) to fire a notification on the
-- events that create a new pending request or accept one.
create or replace function public.send_friend_request(p_username text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_target uuid;
    v_a uuid;
    v_b uuid;
    v_row public.friendships%rowtype;
    v_actor text;
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    select p.id into v_target
    from public.profiles p
    where p.username = lower(trim(p_username)) and p.is_active;

    if v_target is null then
        raise exception 'user_not_found';
    end if;
    if v_target = auth.uid() then
        raise exception 'cannot_friend_self';
    end if;

    v_a := least(auth.uid(), v_target);
    v_b := greatest(auth.uid(), v_target);

    select p.username into v_actor from public.profiles p where p.id = auth.uid();

    select * into v_row from public.friendships where user_a = v_a and user_b = v_b;

    if not found then
        insert into public.friendships (user_a, user_b, status, requested_by)
        values (v_a, v_b, 'pending', auth.uid());
        perform public.notify_user(v_target, 'friend_request', v_actor);
    elsif v_row.status = 'accepted' then
        raise exception 'already_friends';
    elsif v_row.status = 'pending' then
        raise exception 'request_already_pending';
    elsif v_row.requested_by = auth.uid() then
        -- Caller was declined before; do not allow spamming re-requests.
        raise exception 'request_declined';
    else
        -- The previous decliner is now the requester: revive the pair.
        update public.friendships
        set status = 'pending', requested_by = auth.uid(),
            created_at = now(), responded_at = null
        where user_a = v_a and user_b = v_b;
        perform public.notify_user(v_target, 'friend_request', v_actor);
    end if;
end;
$$;

create or replace function public.accept_friend_request(p_requester uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor text;
begin
    update public.friendships
    set status = 'accepted', responded_at = now()
    where user_a = least(auth.uid(), p_requester)
      and user_b = greatest(auth.uid(), p_requester)
      and status = 'pending'
      and requested_by = p_requester
      and requested_by <> auth.uid();

    if not found then
        raise exception 'request_not_found';
    end if;

    select p.username into v_actor from public.profiles p where p.id = auth.uid();
    perform public.notify_user(p_requester, 'friend_accept', v_actor);
end;
$$;

-- notify_user is internal — only the definer RPCs above call it.
revoke execute on function public.notify_user from anon, public;
revoke execute on function public.send_friend_request from anon, public;
revoke execute on function public.accept_friend_request from anon, public;
grant execute on function public.send_friend_request to authenticated;
grant execute on function public.accept_friend_request to authenticated;
