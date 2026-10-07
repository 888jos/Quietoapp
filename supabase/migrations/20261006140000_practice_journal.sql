-- Practice journal behind badges and the streak: guided sessions, breathing,
-- background sounds and check-ins. Written by the iOS app (idempotent on
-- client_entry_id) and read back after a reinstall or on another iPhone.
create table public.practice_entries (
  id bigint generated always as identity primary key,
  user_id text not null references public.profiles(user_id) on delete cascade,
  client_entry_id uuid not null,
  kind text not null check (kind in ('meditation', 'breathing', 'sound', 'check_in')),
  -- A catalogue session, an ambience or a situation id: not a foreign key.
  content_id text not null check (char_length(content_id) between 1 and 120),
  seconds integer not null default 0 check (seconds between 0 and 86400),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (user_id, client_entry_id)
);

create index practice_entries_user_time_idx on public.practice_entries (user_id, occurred_at);

grant select, insert on public.practice_entries to authenticated;

alter table public.practice_entries enable row level security;

create policy practice_read_own on public.practice_entries for select to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy practice_insert_own on public.practice_entries for insert to authenticated
  with check (user_id = (select auth.jwt()->>'sub'));
create policy quieto_identity_only on public.practice_entries as restrictive for all to authenticated
  using ((select public.is_quieto_identity())) with check ((select public.is_quieto_identity()));
