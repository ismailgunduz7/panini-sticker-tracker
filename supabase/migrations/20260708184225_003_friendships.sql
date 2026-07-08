-- Mutual friendships. One row per pair, normalized with user_a < user_b so a
-- pair can never appear twice in either order. All state changes go through
-- RPCs; clients can only read. A declined row is kept so the declined
-- requester cannot immediately re-request — only the decliner can revive the
-- pair by sending a request themselves.

create table public.friendships (
    user_a uuid not null references public.profiles (id) on delete cascade,
    user_b uuid not null references public.profiles (id) on delete cascade,
    status text not null,
    requested_by uuid not null,
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    primary key (user_a, user_b),
    constraint ordered_pair check (user_a < user_b),
    constraint valid_status check (status in ('pending', 'accepted', 'declined')),
    constraint requester_is_participant check (requested_by in (user_a, user_b))
);

alter table public.friendships enable row level security;

create policy "participants read friendships"
    on public.friendships for select
    using (auth.uid() in (user_a, user_b));

-- Now that friendships exists: accepted friends may read each other's profile
-- rows directly (needed for friend list display and privacy-setting lookups).
create policy "friends read profile"
    on public.profiles for select
    using (
        exists (
            select 1 from public.friendships f
            where f.status = 'accepted'
              and ((f.user_a = auth.uid() and f.user_b = profiles.id)
                or (f.user_b = auth.uid() and f.user_a = profiles.id))
        )
    );

-- Sends a friend request to the given username.
-- Raises 'user_not_found', 'cannot_friend_self', 'already_friends',
-- 'request_already_pending' or 'request_declined'.
create function public.send_friend_request(p_username text)
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

    select * into v_row from public.friendships where user_a = v_a and user_b = v_b;

    if not found then
        insert into public.friendships (user_a, user_b, status, requested_by)
        values (v_a, v_b, 'pending', auth.uid());
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
    end if;
end;
$$;

-- Accepts a pending request sent by p_requester to the caller.
create function public.accept_friend_request(p_requester uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
end;
$$;

-- Declines a pending request sent by p_requester to the caller.
create function public.decline_friend_request(p_requester uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.friendships
    set status = 'declined', responded_at = now()
    where user_a = least(auth.uid(), p_requester)
      and user_b = greatest(auth.uid(), p_requester)
      and status = 'pending'
      and requested_by = p_requester
      and requested_by <> auth.uid();

    if not found then
        raise exception 'request_not_found';
    end if;
end;
$$;

-- Removes an accepted friendship, or cancels the caller's own pending request.
create function public.remove_friendship(p_other uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    delete from public.friendships
    where user_a = least(auth.uid(), p_other)
      and user_b = greatest(auth.uid(), p_other)
      and (status = 'accepted' or (status = 'pending' and requested_by = auth.uid()));

    if not found then
        raise exception 'friendship_not_found';
    end if;
end;
$$;

-- Read-only for clients; all writes go through the definer RPCs above.
grant select on public.friendships to authenticated;

revoke execute on function public.send_friend_request from anon, public;
revoke execute on function public.accept_friend_request from anon, public;
revoke execute on function public.decline_friend_request from anon, public;
revoke execute on function public.remove_friendship from anon, public;
grant execute on function public.send_friend_request to authenticated;
grant execute on function public.accept_friend_request to authenticated;
grant execute on function public.decline_friend_request to authenticated;
grant execute on function public.remove_friendship to authenticated;
