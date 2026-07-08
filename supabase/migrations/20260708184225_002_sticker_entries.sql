-- Server-side mirror of the local SwiftData StickerEntry rows. The device
-- stays the source of truth; this table exists so friends can compute trade
-- matches. Rows are lazily created (only stickers the user interacted with),
-- matching the local model. updated_at drives last-write-wins merging.

create table public.sticker_entries (
    user_id uuid not null references public.profiles (id) on delete cascade,
    code text not null,
    is_owned boolean not null default false,
    duplicate_count integer not null default 0,
    updated_at timestamptz not null default now(),
    primary key (user_id, code),
    constraint duplicate_count_nonnegative check (duplicate_count >= 0),
    constraint code_length check (char_length(code) between 1 and 16)
);

alter table public.sticker_entries enable row level security;

-- Only the owner touches their rows directly. Friends never read this table;
-- they go through get_friend_collection, which enforces the privacy setting.
create policy "read own entries"
    on public.sticker_entries for select
    using (user_id = auth.uid());

create policy "insert own entries"
    on public.sticker_entries for insert
    with check (user_id = auth.uid());

create policy "update own entries"
    on public.sticker_entries for update
    using (user_id = auth.uid())
    with check (user_id = auth.uid());

-- Batched last-write-wins upsert. The client sends its dirty entries
-- (updatedAt > lastSyncedAt) as a JSON array; a row only overwrites the
-- server copy when it is at least as new, so two devices syncing the same
-- account converge on the most recent state per sticker. A full-album reset
-- syncs as isOwned=false upserts through this same path (never row deletes),
-- otherwise the pre-reset state would merge back on the next pull.
create function public.upsert_sticker_entries(p_entries jsonb)
returns void
language sql
security invoker
set search_path = ''
as $$
    insert into public.sticker_entries (user_id, code, is_owned, duplicate_count, updated_at)
    select
        auth.uid(),
        e ->> 'code',
        (e ->> 'is_owned')::boolean,
        (e ->> 'duplicate_count')::integer,
        (e ->> 'updated_at')::timestamptz
    from jsonb_array_elements(p_entries) as e
    on conflict (user_id, code) do update set
        is_owned = excluded.is_owned,
        duplicate_count = excluded.duplicate_count,
        updated_at = excluded.updated_at
    where excluded.updated_at >= sticker_entries.updated_at;
$$;

-- Explicit table grants (auto-expose is disabled). upsert_sticker_entries is
-- security invoker, so it relies on these same grants plus the RLS policies.
grant select, insert, update on public.sticker_entries to authenticated;

revoke execute on function public.upsert_sticker_entries from anon, public;
grant execute on function public.upsert_sticker_entries to authenticated;
