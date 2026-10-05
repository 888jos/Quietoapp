-- Quieto / Firebase -> Supabase transition schema.
-- User identifiers are text on purpose: Firebase UIDs and Supabase UUIDs must
-- coexist during the zero-downtime authentication migration.

create schema if not exists private;
create schema if not exists migration;

revoke all on schema private from public, anon, authenticated;
revoke all on schema migration from public, anon, authenticated;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function private.set_updated_at() from public, anon, authenticated;

create or replace function public.is_quieto_identity()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when auth.jwt() is null then false
    when auth.jwt()->>'iss' = 'https://securetoken.google.com/quieto-06'
      then auth.jwt()->>'aud' = 'quieto-06'
    else (auth.jwt()->>'iss') ~ '^https://[a-z0-9-]+\.supabase\.co/auth/v1$'
  end;
$$;

revoke all on function public.is_quieto_identity() from public;
grant execute on function public.is_quieto_identity() to authenticated;

create table public.profiles (
  user_id text primary key,
  firebase_uid text unique,
  first_name text,
  locale text not null default 'fr' check (locale in ('fr', 'en', 'es', 'de', 'ja', 'ko')),
  is_anonymous boolean not null default true,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(user_id) between 1 and 128),
  check (first_name is null or length(first_name) <= 80)
);

create table public.user_preferences (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  reminder_enabled boolean not null default false,
  reminder_days smallint[] not null default array[1,2,3,4,5,6,7]::smallint[],
  reminder_local_time time,
  reminder_timezone text,
  ambient_level numeric(4,3) not null default 0 check (ambient_level between 0 and 1),
  reduce_motion boolean not null default false,
  larger_text boolean not null default false,
  health_prompt_seen boolean not null default false,
  raw_preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  check (reminder_days <@ array[1,2,3,4,5,6,7]::smallint[])
);

create table public.sessions (
  id text primary key,
  title jsonb not null,
  subtitle jsonb not null default '{}'::jsonb,
  intention jsonb not null default '{}'::jsonb,
  duration_seconds integer not null check (duration_seconds > 0),
  category_id text not null,
  pillar text not null check (pillar in ('sleep', 'stress', 'thoughts', 'emotions')),
  practice_type text not null check (practice_type in ('meditation', 'breathing', 'relaxation', 'visualization', 'anchoring', 'self_compassion')),
  keywords text[] not null default '{}',
  artwork_path text,
  audio_path text,
  is_premium boolean not null default true,
  is_active boolean not null default true,
  catalog_version integer not null default 1,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index sessions_discovery_idx on public.sessions (is_active, pillar, practice_type, duration_seconds);
create index sessions_keywords_idx on public.sessions using gin (keywords);

create table public.session_progress (
  user_id text not null references public.profiles(user_id) on delete cascade,
  session_id text not null references public.sessions(id) on delete cascade,
  last_position_seconds integer not null default 0 check (last_position_seconds >= 0),
  listened_seconds bigint not null default 0 check (listened_seconds >= 0),
  play_count integer not null default 0 check (play_count >= 0),
  completed_count integer not null default 0 check (completed_count >= 0),
  last_played_at timestamptz,
  completed_at timestamptz,
  is_favorite boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, session_id)
);

create index session_progress_user_recent_idx on public.session_progress (user_id, last_played_at desc);
create index session_progress_user_favorite_idx on public.session_progress (user_id, is_favorite) where is_favorite;
create index session_progress_session_id_idx on public.session_progress (session_id);

create table public.listening_events (
  id bigint generated always as identity primary key,
  user_id text not null references public.profiles(user_id) on delete cascade,
  session_id text not null references public.sessions(id) on delete restrict,
  event_type text not null check (event_type in ('started', 'paused', 'resumed', 'seeked', 'completed', 'stopped')),
  position_seconds integer not null default 0 check (position_seconds >= 0),
  listened_delta_seconds integer not null default 0 check (listened_delta_seconds >= 0),
  client_event_id uuid not null,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  device_id text,
  unique (user_id, client_event_id)
);

create index listening_events_user_time_idx on public.listening_events (user_id, occurred_at desc);
create index listening_events_session_id_idx on public.listening_events (session_id);

create table public.programs (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.profiles(user_id) on delete cascade,
  title text not null,
  status text not null default 'active' check (status in ('active', 'completed', 'abandoned')),
  source text not null default 'louane' check (source in ('louane', 'catalog', 'migration')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  raw_program jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index programs_one_active_per_user_idx on public.programs(user_id) where status = 'active';
create index programs_user_created_idx on public.programs (user_id, created_at desc);

create table public.program_steps (
  program_id uuid not null references public.programs(id) on delete cascade,
  step_number smallint not null check (step_number > 0),
  session_id text not null references public.sessions(id) on delete restrict,
  louane_note text,
  status text not null default 'planned' check (status in ('planned', 'available', 'completed', 'skipped')),
  completed_at timestamptz,
  primary key (program_id, step_number)
);

create index program_steps_session_id_idx on public.program_steps(session_id);

create table public.louane_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.profiles(user_id) on delete cascade,
  title text,
  is_temporary boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index louane_conversations_user_updated_idx on public.louane_conversations(user_id, updated_at desc);

create table public.louane_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.louane_conversations(id) on delete cascade,
  user_id text not null references public.profiles(user_id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null check (length(content) between 1 and 4000),
  status text not null default 'complete' check (status in ('sending', 'streaming', 'complete', 'failed', 'cancelled')),
  client_message_id uuid,
  recommendation jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, client_message_id)
);

create index louane_messages_conversation_time_idx on public.louane_messages(conversation_id, created_at);
create index louane_messages_user_id_idx on public.louane_messages(user_id);

create table public.louane_memory (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  memory_text text not null default '' check (length(memory_text) <= 4000),
  memory_items jsonb not null default '[]'::jsonb,
  consented_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.subscription_accounts (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  revenuecat_app_user_id text unique,
  original_app_user_id text,
  entitlement_id text not null default 'premium',
  status text not null default 'unknown' check (status in ('unknown', 'inactive', 'trial', 'active', 'grace_period', 'billing_issue', 'expired', 'promotional')),
  product_id text,
  store text,
  environment text,
  expires_at timestamptz,
  will_renew boolean,
  source text not null default 'revenuecat' check (source in ('revenuecat', 'superwall', 'app_store', 'play_store', 'enterprise', 'migration')),
  source_updated_at timestamptz,
  raw_customer_info jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index subscription_accounts_status_expiry_idx on public.subscription_accounts(status, expires_at);

create table public.subscription_events (
  id bigint generated always as identity primary key,
  source text not null check (source in ('revenuecat', 'superwall', 'app_store', 'play_store', 'migration')),
  source_event_id text not null,
  user_id text,
  event_type text not null,
  occurred_at timestamptz,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_error text,
  unique (source, source_event_id)
);

create index subscription_events_user_time_idx on public.subscription_events(user_id, occurred_at desc);

create table public.enterprise_access (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  firebase_enterprise_id text not null,
  enterprise_name text,
  granted_until timestamptz,
  raw_data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table migration.runs (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  phase text not null check (phase in ('snapshot', 'import', 'verification', 'cutover')),
  status text not null check (status in ('running', 'succeeded', 'failed')),
  source_project text,
  manifest_sha256 text,
  record_counts jsonb not null default '{}'::jsonb,
  notes text,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

create table migration.firebase_auth_users (
  firebase_uid text primary key,
  email text,
  is_anonymous boolean not null default false,
  disabled boolean not null default false,
  providers jsonb not null default '[]'::jsonb,
  custom_claims jsonb not null default '{}'::jsonb,
  raw_user jsonb not null,
  exported_at timestamptz not null default now()
);

create table migration.firebase_documents (
  collection_path text not null,
  document_id text not null,
  raw_data jsonb not null,
  create_time timestamptz,
  update_time timestamptz,
  exported_at timestamptz not null default now(),
  primary key (collection_path, document_id)
);

create index firebase_documents_collection_idx on migration.firebase_documents(collection_path);

create table migration.revenuecat_customers (
  app_user_id text primary key,
  original_app_user_id text,
  aliases text[] not null default '{}',
  raw_customer jsonb not null,
  fetched_at timestamptz not null default now()
);

create table migration.checksums (
  run_id uuid not null references migration.runs(id) on delete cascade,
  source_object text not null,
  row_count bigint not null check (row_count >= 0),
  sha256 text not null,
  checked_at timestamptz not null default now(),
  primary key (run_id, source_object)
);

grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon, authenticated;
grant select on public.sessions to anon, authenticated;
grant select, insert, update on public.profiles, public.user_preferences, public.session_progress,
  public.programs, public.program_steps, public.louane_conversations, public.louane_messages,
  public.louane_memory to authenticated;
grant insert on public.listening_events to authenticated;
grant select on public.listening_events, public.subscription_accounts, public.subscription_events,
  public.enterprise_access to authenticated;
grant usage, select on all sequences in schema public to authenticated;

alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.sessions enable row level security;
alter table public.session_progress enable row level security;
alter table public.listening_events enable row level security;
alter table public.programs enable row level security;
alter table public.program_steps enable row level security;
alter table public.louane_conversations enable row level security;
alter table public.louane_messages enable row level security;
alter table public.louane_memory enable row level security;
alter table public.subscription_accounts enable row level security;
alter table public.subscription_events enable row level security;
alter table public.enterprise_access enable row level security;

create policy sessions_public_read on public.sessions for select to anon, authenticated using (is_active);

create policy profiles_read_own on public.profiles for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));
create policy profiles_update_own on public.profiles for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy preferences_read_own on public.user_preferences for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy preferences_insert_own on public.user_preferences for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));
create policy preferences_update_own on public.user_preferences for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy progress_read_own on public.session_progress for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy progress_insert_own on public.session_progress for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));
create policy progress_update_own on public.session_progress for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy listening_read_own on public.listening_events for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy listening_insert_own on public.listening_events for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));

create policy programs_read_own on public.programs for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy programs_insert_own on public.programs for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));
create policy programs_update_own on public.programs for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy program_steps_read_own on public.program_steps for select to authenticated using (
  exists (select 1 from public.programs p where p.id = program_id and p.user_id = (select auth.jwt()->>'sub'))
);
create policy program_steps_insert_own on public.program_steps for insert to authenticated with check (
  exists (select 1 from public.programs p where p.id = program_id and p.user_id = (select auth.jwt()->>'sub'))
);
create policy program_steps_update_own on public.program_steps for update to authenticated
  using (exists (select 1 from public.programs p where p.id = program_id and p.user_id = (select auth.jwt()->>'sub')))
  with check (exists (select 1 from public.programs p where p.id = program_id and p.user_id = (select auth.jwt()->>'sub')));

create policy conversations_read_own on public.louane_conversations for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy conversations_insert_own on public.louane_conversations for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));
create policy conversations_update_own on public.louane_conversations for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy messages_read_own on public.louane_messages for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy messages_insert_own on public.louane_messages for insert to authenticated with check (
  user_id = (select auth.jwt()->>'sub') and exists (
    select 1 from public.louane_conversations c where c.id = conversation_id and c.user_id = (select auth.jwt()->>'sub')
  )
);
create policy messages_update_own on public.louane_messages for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy memory_read_own on public.louane_memory for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy memory_insert_own on public.louane_memory for insert to authenticated with check (user_id = (select auth.jwt()->>'sub'));
create policy memory_update_own on public.louane_memory for update to authenticated
  using (user_id = (select auth.jwt()->>'sub')) with check (user_id = (select auth.jwt()->>'sub'));

create policy subscriptions_read_own on public.subscription_accounts for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy subscription_events_read_own on public.subscription_events for select to authenticated using (user_id = (select auth.jwt()->>'sub'));
create policy enterprise_access_read_own on public.enterprise_access for select to authenticated using (user_id = (select auth.jwt()->>'sub'));

-- Every authenticated table gets an additional restrictive identity check.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'profiles','user_preferences','session_progress','listening_events','programs','program_steps',
    'louane_conversations','louane_messages','louane_memory','subscription_accounts','subscription_events','enterprise_access'
  ] loop
    execute format(
      'create policy quieto_identity_only on public.%I as restrictive for all to authenticated using ((select public.is_quieto_identity())) with check ((select public.is_quieto_identity()))',
      table_name
    );
  end loop;
end $$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute function private.set_updated_at();
create trigger preferences_set_updated_at before update on public.user_preferences for each row execute function private.set_updated_at();
create trigger sessions_set_updated_at before update on public.sessions for each row execute function private.set_updated_at();
create trigger session_progress_set_updated_at before update on public.session_progress for each row execute function private.set_updated_at();
create trigger programs_set_updated_at before update on public.programs for each row execute function private.set_updated_at();
create trigger conversations_set_updated_at before update on public.louane_conversations for each row execute function private.set_updated_at();
create trigger memory_set_updated_at before update on public.louane_memory for each row execute function private.set_updated_at();
create trigger subscriptions_set_updated_at before update on public.subscription_accounts for each row execute function private.set_updated_at();
create trigger enterprise_access_set_updated_at before update on public.enterprise_access for each row execute function private.set_updated_at();

comment on schema migration is 'Immutable raw Firebase and RevenueCat migration evidence. Service/database roles only.';
comment on table public.subscription_accounts is 'Server-managed entitlement projection. Clients can only read their own row.';
comment on table migration.firebase_documents is 'Raw lossless Firestore snapshot, including nested collection paths.';
