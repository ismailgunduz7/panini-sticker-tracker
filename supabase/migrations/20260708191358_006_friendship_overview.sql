-- One-call overview for the Friends screen: every pending or accepted
-- friendship of the caller, joined with the counterpart's public profile
-- fields. Security definer because RLS only lets accepted friends read each
-- other's profiles, yet the requests UI must show who is asking. Declined
-- rows are omitted on purpose: the declined requester sees nothing, and the
-- decliner can revive the pair by sending a request via search.

create function public.get_friendships()
returns table (
    user_id uuid,
    username text,
    display_name text,
    status text,
    requested_by_me boolean,
    created_at timestamptz
)
language sql
security definer
set search_path = ''
stable
as $$
    select
        p.id,
        p.username,
        p.display_name,
        f.status,
        f.requested_by = auth.uid(),
        f.created_at
    from public.friendships f
    join public.profiles p
      on p.id = case when f.user_a = auth.uid() then f.user_b else f.user_a end
    where auth.uid() in (f.user_a, f.user_b)
      and f.status in ('pending', 'accepted')
      and p.is_active
    order by f.created_at desc;
$$;

revoke execute on function public.get_friendships from anon, public;
grant execute on function public.get_friendships to authenticated;
