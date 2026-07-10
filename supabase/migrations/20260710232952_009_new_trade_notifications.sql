-- Push notification when a user's newly registered spare opens a *new* trade
-- with a friend. The client detects the 0->1 duplicate transition and calls
-- this RPC with the affected codes; here we fan out to accepted friends who
-- are missing at least one of them, one summary notification per friend.
-- "Missing" mirrors get_friend_collection's needs test (no owned row). We
-- trust the client's announced codes rather than re-checking the caller's own
-- spares, since the debounced sticker_entries push may not have landed yet.

create function public.announce_new_spares(p_codes text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor text;
    v_friend uuid;
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    if p_codes is null or array_length(p_codes, 1) is null then
        return;
    end if;

    select p.username into v_actor from public.profiles p where p.id = auth.uid();

    for v_friend in
        select case when f.user_a = auth.uid() then f.user_b else f.user_a end
        from public.friendships f
        where f.status = 'accepted' and auth.uid() in (f.user_a, f.user_b)
    loop
        -- Notify once if this friend is missing at least one announced code.
        if exists (
            select 1 from unnest(p_codes) as c
            where not exists (
                select 1 from public.sticker_entries s
                where s.user_id = v_friend and s.code = c and s.is_owned
            )
        ) then
            perform public.notify_user(v_friend, 'new_trade', v_actor);
        end if;
    end loop;
end;
$$;

revoke execute on function public.announce_new_spares from anon, public;
grant execute on function public.announce_new_spares to authenticated;
