-- Account lifecycle. Sign-out is handled client-side by flipping
-- profiles.is_active to false (own-row update policy already allows it);
-- friends then stop seeing the frozen collection via the RPC guards.
-- Deletion is the permanent path (App Store requirement): removing the
-- auth.users row cascades to profiles, which cascades to sticker_entries and
-- friendships, and frees the username. Local device data is untouched.

create function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_account from anon, public;
grant execute on function public.delete_account to authenticated;
