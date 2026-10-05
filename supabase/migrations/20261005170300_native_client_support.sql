-- Native iOS support: product analytics, safe self-service export/deletion,
-- and private durable audio objects. Firebase/RevenueCat raw migration tables
-- remain immutable and are intentionally untouched.

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.profiles(user_id) on delete cascade,
  event_name text not null check (length(event_name) between 1 and 80),
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  client_event_id uuid not null,
  unique (user_id, client_event_id)
);

create index analytics_events_user_time_idx on public.analytics_events(user_id, occurred_at desc);
alter table public.analytics_events enable row level security;
grant insert, select on public.analytics_events to authenticated;

create policy analytics_read_own on public.analytics_events for select to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy analytics_insert_own on public.analytics_events for insert to authenticated
  with check (user_id = (select auth.jwt()->>'sub'));
create policy analytics_identity_only on public.analytics_events as restrictive for all to authenticated
  using ((select public.is_quieto_identity())) with check ((select public.is_quieto_identity()));

-- Users may explicitly delete their own product rows. Subscription history and
-- migration evidence stay server-managed; the account-data Edge Function owns
-- their deletion and the final auth.users removal.
create policy conversations_delete_own on public.louane_conversations for delete to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy messages_delete_own on public.louane_messages for delete to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy memory_delete_own on public.louane_memory for delete to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy progress_delete_own on public.session_progress for delete to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy preferences_delete_own on public.user_preferences for delete to authenticated
  using (user_id = (select auth.jwt()->>'sub'));
create policy programs_delete_own on public.programs for delete to authenticated
  using (user_id = (select auth.jwt()->>'sub'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('session-audio', 'session-audio', false, 104857600, array['audio/mpeg','audio/mp4','audio/x-m4a','audio/wav'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy premium_audio_read on storage.objects for select to authenticated using (
  bucket_id = 'session-audio' and (
    exists (
      select 1 from public.subscription_accounts s
      where s.user_id = (select auth.jwt()->>'sub')
        and s.status in ('trial','active','grace_period','promotional')
        and (s.expires_at is null or s.expires_at > now())
    )
    or exists (
      select 1 from public.sessions q
      where q.audio_path = storage.objects.name and q.is_premium = false and q.is_active
    )
  )
);

