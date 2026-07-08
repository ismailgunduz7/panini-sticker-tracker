-- Profiles: one row per authenticated user. Username is the public handle
-- used for friend search; display_name is free-form. is_active gates all
-- friend-facing visibility (sign-out sets it false). share_full_album is the
-- single privacy toggle: false (default) = friends see only the trade
-- intersection, true = friends see the whole album.

create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    -- Plain text, always lowercase: claim_profile normalizes and the format
    -- constraint rejects anything else, so no citext needed.
    username text not null unique,
    display_name text not null default '',
    share_full_album boolean not null default false,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint username_format check (username ~ '^[a-z0-9_.]{3,20}$'),
    constraint display_name_length check (char_length(display_name) <= 50)
);

-- Handles that must never become user handles.
create table public.reserved_usernames (
    username text primary key
);

insert into public.reserved_usernames (username) values
    ('admin'), ('administrator'), ('root'), ('support'), ('help'),
    ('moderator'), ('mod'), ('system'), ('panini'), ('stickertracker'),
    ('official'), ('info'), ('contact'), ('api'), ('test');

alter table public.profiles enable row level security;
alter table public.reserved_usernames enable row level security;

-- Own profile: full read/write. Friends' profiles become readable in the
-- friendships migration (policy needs that table to exist first). Everyone
-- else goes through search_profiles below, which exposes only safe columns.
create policy "read own profile"
    on public.profiles for select
    using (id = auth.uid());

create policy "update own profile"
    on public.profiles for update
    using (id = auth.uid())
    with check (id = auth.uid());

-- No insert policy: profiles are created only via claim_profile so that
-- username validation and reservation checks cannot be bypassed.

-- Atomically validates and claims a username, creating the caller's profile.
-- Raises 'username_invalid', 'username_reserved' or 'username_taken'.
create function public.claim_profile(p_username text, p_display_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_username text := lower(trim(p_username));
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    if v_username !~ '^[a-z0-9_.]{3,20}$' then
        raise exception 'username_invalid';
    end if;

    if exists (select 1 from public.reserved_usernames r where r.username = v_username) then
        raise exception 'username_reserved';
    end if;

    begin
        insert into public.profiles (id, username, display_name)
        values (auth.uid(), v_username, left(trim(p_display_name), 50));
    exception when unique_violation then
        raise exception 'username_taken';
    end;
end;
$$;

-- Prefix search over active profiles, exposing only public-safe columns.
create function public.search_profiles(p_query text)
returns table (id uuid, username text, display_name text)
language sql
security definer
set search_path = ''
stable
as $$
    select p.id, p.username, p.display_name
    from public.profiles p
    where p.is_active
      and p.id <> auth.uid()
      and p.username like lower(trim(p_query)) || '%'
      and char_length(trim(p_query)) >= 2
    order by p.username
    limit 20;
$$;

-- "Automatically expose new tables" is disabled on the project, so table
-- access is granted explicitly. RLS policies above still scope the rows.
-- reserved_usernames gets no grants: only definer functions read it.
grant select, update on public.profiles to authenticated;

revoke execute on function public.claim_profile from anon, public;
revoke execute on function public.search_profiles from anon, public;
grant execute on function public.claim_profile to authenticated;
grant execute on function public.search_profiles to authenticated;
