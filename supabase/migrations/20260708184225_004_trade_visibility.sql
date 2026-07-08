-- The only way one user sees another's collection. Enforces, server-side:
-- the pair must be accepted friends, the friend must be active, and the
-- friend's share_full_album setting decides how much is returned.
--
-- share_full_album = true : every row the friend has, so the client can run
--   its full TradeMatch logic locally.
-- share_full_album = false: only the trade intersection —
--   * rows the friend can offer the caller (friend has a spare, caller lacks it)
--   * synthesized rows for stickers the caller could offer the friend
--     (caller has a spare, friend does not own it) as is_owned=false rows.
-- "Not owning" includes stickers with no row at all (rows are lazy), which is
-- why the needs side is driven from the caller's spares, not the album list.

create function public.get_friend_collection(p_friend uuid)
returns table (code text, is_owned boolean, duplicate_count integer, updated_at timestamptz)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
    v_share_full boolean;
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    select p.share_full_album into v_share_full
    from public.profiles p
    join public.friendships f
      on f.user_a = least(auth.uid(), p_friend)
     and f.user_b = greatest(auth.uid(), p_friend)
     and f.status = 'accepted'
    where p.id = p_friend and p.is_active and p_friend <> auth.uid();

    if v_share_full is null then
        raise exception 'not_friends';
    end if;

    if v_share_full then
        return query
        select s.code, s.is_owned, s.duplicate_count, s.updated_at
        from public.sticker_entries s
        where s.user_id = p_friend;
    else
        return query
        -- Friend's spares the caller does not own yet.
        select s.code, s.is_owned, s.duplicate_count, s.updated_at
        from public.sticker_entries s
        where s.user_id = p_friend
          and s.duplicate_count > 0
          and not exists (
              select 1 from public.sticker_entries mine
              where mine.user_id = auth.uid()
                and mine.code = s.code and mine.is_owned
          )
        union all
        -- Caller's spares the friend does not own (synthesized "needs" rows).
        select mine.code, false, 0, null::timestamptz
        from public.sticker_entries mine
        where mine.user_id = auth.uid()
          and mine.duplicate_count > 0
          and not exists (
              select 1 from public.sticker_entries theirs
              where theirs.user_id = p_friend
                and theirs.code = mine.code and theirs.is_owned
          );
    end if;
end;
$$;

-- Freshness for the "last updated X ago" label, regardless of privacy setting.
create function public.get_friend_last_updated(p_friend uuid)
returns timestamptz
language sql
security definer
set search_path = ''
stable
as $$
    select max(s.updated_at)
    from public.sticker_entries s
    where s.user_id = p_friend
      and exists (
          select 1 from public.friendships f
          where f.user_a = least(auth.uid(), p_friend)
            and f.user_b = greatest(auth.uid(), p_friend)
            and f.status = 'accepted'
      );
$$;

revoke execute on function public.get_friend_collection from anon, public;
revoke execute on function public.get_friend_last_updated from anon, public;
grant execute on function public.get_friend_collection to authenticated;
grant execute on function public.get_friend_last_updated to authenticated;
