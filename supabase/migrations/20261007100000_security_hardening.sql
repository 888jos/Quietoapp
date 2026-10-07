-- Security hardening (audit of 06/10/2026). Idempotent where PostgreSQL
-- allows it: every function is `create or replace`, every trigger, policy and
-- constraint is dropped first.
--
--  1. Dashboard admins: Supabase Auth identity + confirmed email only.
--  2. Store transactions: a device claim cannot steal another account's
--     subscription (appAccountToken, fresh JWS, 24 h between transfers).
--  3. Sandbox purchases grant nothing outside private.sandbox_testers.
--  4. Generic per-subject rate limits + Louane in-flight lock.
--  5. Bounds on client-written rows (analytics, practice journal, raw jsonb).
--  6. Table privileges: practice_entries, TRUNCATE/REFERENCES/TRIGGER, defaults.
--  7. user_has_premium(): any active store subscription of the user counts.
--  8. Legacy Firebase link: the subscription moves, it is not duplicated.
--  9. Erasure: store subscriptions anonymised, subscription events purged.
-- 10. Retention: private.purge_expired_data(), scheduled with pg_cron if any.

-- ---------------------------------------------------------------------------
-- 1. Dashboard admins. The project also accepts Firebase tokens (third-party
--    auth), whose `email` claim is not one Supabase ever verified: only a
--    Supabase Auth session whose auth.users email is confirmed counts.

create or replace function public.is_dashboard_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  claims jsonb := auth.jwt();
begin
  if claims is null or claims->>'role' is distinct from 'authenticated' then
    return false;
  end if;
  if coalesce(claims->>'iss', '') !~ '^https://[a-z0-9-]+\.supabase\.co/auth/v1$' then
    return false;
  end if;
  -- Checked before any uuid cast (auth.uid() raises on a non-uuid subject).
  if coalesce(claims->>'sub', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return exists (
    select 1
    from auth.users u
    join private.dashboard_admins a on a.email = lower(u.email)
    where u.id = (claims->>'sub')::uuid
      and u.email_confirmed_at is not null
      and coalesce(u.is_anonymous, false) = false
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until < now())
  );
end;
$$;

revoke all on function public.is_dashboard_admin() from public, anon;
grant execute on function public.is_dashboard_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Sandbox testers. TestFlight / Sandbox / Xcode purchases are free, so they
--    only grant access to these accounts. Keep in sync with the Edge Function
--    secret QUIETO_SANDBOX_USER_IDS (which gates the writes):
--      insert into private.sandbox_testers (user_id) values ('<supabase uuid>');

create table if not exists private.sandbox_testers (
  user_id text primary key check (user_id = lower(user_id) and length(user_id) between 1 and 128),
  note text,
  added_at timestamptz not null default now()
);
revoke all on private.sandbox_testers from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Store subscriptions: ownership transfer rule.
--
--    A StoreKit JWS proves that a device holds the Apple ID, not that the
--    caller bought the subscription, and an old JWS can be replayed forever.
--    On a device claim (p_transfer = true, subscription-sync only) the
--    transaction is bound to the claimant when:
--      a. it is bound to nobody (or already to the claimant), or
--      b. its appAccountToken is the claimant's id (Superwall sets it to the
--         Supabase UUID at purchase; compared in lowercase), or
--      c. the JWS was signed less than 10 minutes ago (StoreKit re-signs on
--         AppStore.sync / a fresh purchase) AND the transaction has not moved
--         between accounts in the last 24 hours (last_transferred_at).
--    Otherwise the state is still updated (it is Apple-signed) but the owner
--    does not change: the call succeeds without granting access.
--    Webhooks (p_transfer = false) never move a bound transaction.

alter table private.store_subscriptions add column if not exists last_transferred_at timestamptz;

drop function if exists public.apply_store_subscription(text, text, boolean, text, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz, jsonb);

create or replace function public.apply_store_subscription(
  p_original_transaction_id text,
  p_user_id text,
  p_transfer boolean,
  p_source text,
  p_status text,
  p_product_id text,
  p_store text,
  p_environment text,
  p_period_type text,
  p_expires_at timestamptz,
  p_revoked_at timestamptz,
  p_will_renew boolean,
  p_event_at timestamptz,
  p_raw jsonb,
  p_app_account_token text default null,
  p_signed_at timestamptz default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_row private.store_subscriptions%rowtype;
  target_user text;
  candidate_exists boolean;
  is_stale boolean := false;
  event_at timestamptz := coalesce(p_event_at, now());
  claim_token text := lower(nullif(btrim(coalesce(p_app_account_token, '')), ''));
begin
  if p_original_transaction_id is null or length(p_original_transaction_id) = 0 then
    raise exception 'original_transaction_id required';
  end if;
  if p_source not in ('superwall', 'app_store', 'revenuecat', 'migration') then
    raise exception 'unknown source %', p_source;
  end if;

  insert into private.store_subscriptions as s
    (original_transaction_id, status, source, last_event_at)
  values (p_original_transaction_id, p_status, p_source, '-infinity')
  on conflict (original_transaction_id) do nothing;

  select * into current_row from private.store_subscriptions
  where original_transaction_id = p_original_transaction_id
  for update;

  select exists (select 1 from public.profiles where user_id = p_user_id) into candidate_exists;

  if p_transfer and candidate_exists then
    if current_row.user_id is null or current_row.user_id = p_user_id then
      target_user := p_user_id;                                   -- rule a
    elsif claim_token is not null and claim_token = lower(p_user_id) then
      target_user := p_user_id;                                   -- rule b
    elsif p_signed_at is not null
      and p_signed_at > now() - interval '10 minutes'
      and p_signed_at < now() + interval '5 minutes'
      and (current_row.last_transferred_at is null
           or current_row.last_transferred_at < now() - interval '24 hours') then
      target_user := p_user_id;                                   -- rule c
    else
      target_user := current_row.user_id;                         -- refused
    end if;
  elsif current_row.user_id is not null then
    target_user := current_row.user_id;
  elsif candidate_exists then
    target_user := p_user_id;
  else
    target_user := null;
  end if;

  -- An older event never overwrites a newer state (RevenueCat/Superwall retries,
  -- re-imports). The binding can still move on an allowed device claim.
  is_stale := event_at < current_row.last_event_at;

  if not is_stale then
    update private.store_subscriptions set
      status = p_status,
      product_id = coalesce(p_product_id, product_id),
      store = coalesce(p_store, store),
      environment = coalesce(p_environment, environment),
      period_type = p_period_type,
      expires_at = p_expires_at,
      revoked_at = p_revoked_at,
      will_renew = p_will_renew,
      source = p_source,
      last_event_at = event_at,
      raw = coalesce(p_raw, '{}'::jsonb),
      updated_at = now()
    where original_transaction_id = p_original_transaction_id
    returning * into current_row;
  end if;

  if target_user is distinct from current_row.user_id then
    -- Release the projection held by the previous owner.
    delete from public.subscription_accounts
    where original_transaction_id = p_original_transaction_id
      and user_id is distinct from target_user;
    update private.store_subscriptions set
      user_id = target_user,
      -- Only a move between two accounts starts the 24 h cool-down.
      last_transferred_at = case when current_row.user_id is not null then now() else last_transferred_at end,
      updated_at = now()
    where original_transaction_id = p_original_transaction_id
    returning * into current_row;
  end if;

  if target_user is null then
    return null;
  end if;

  insert into public.subscription_accounts as a (
    user_id, original_transaction_id, entitlement_id, status, product_id, store, environment,
    period_type, expires_at, revoked_at, will_renew, source, source_updated_at, raw_customer_info
  ) values (
    target_user, current_row.original_transaction_id, 'premium', current_row.status, current_row.product_id,
    current_row.store, current_row.environment, current_row.period_type, current_row.expires_at,
    current_row.revoked_at, current_row.will_renew, current_row.source, current_row.last_event_at,
    current_row.raw
  )
  on conflict (user_id) do update set
    original_transaction_id = excluded.original_transaction_id,
    status = excluded.status,
    product_id = excluded.product_id,
    store = excluded.store,
    environment = excluded.environment,
    period_type = excluded.period_type,
    expires_at = excluded.expires_at,
    revoked_at = excluded.revoked_at,
    will_renew = excluded.will_renew,
    source = excluded.source,
    source_updated_at = excluded.source_updated_at,
    raw_customer_info = excluded.raw_customer_info
  -- Keep the projection on the most recent subscription of this user.
  where a.source_updated_at is null
     or a.original_transaction_id is not distinct from excluded.original_transaction_id
     or a.source_updated_at <= excluded.source_updated_at;

  return target_user;
end;
$$;

revoke all on function public.apply_store_subscription(text, text, boolean, text, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz, jsonb, text, timestamptz) from public, anon, authenticated;
grant execute on function public.apply_store_subscription(text, text, boolean, text, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz, jsonb, text, timestamptz) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Entitlement check. The subscription_accounts projection keeps one row per
--    user (the latest event wins), so a second, still active subscription of
--    the same user could be hidden: every row of private.store_subscriptions
--    counts. Projection rows without a store transaction (RevenueCat import,
--    copied by link_legacy_firebase_account) keep the previous rules.
--    Sandbox rows only count for private.sandbox_testers.

create or replace function public.user_has_premium(p_user_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1 from private.store_subscriptions s
      where s.user_id = p_user_id
        and s.revoked_at is null
        and s.status in ('trial', 'active', 'grace_period', 'billing_issue', 'promotional')
        and s.expires_at > now()
        and (s.environment is null or upper(s.environment) = 'PRODUCTION'
             or exists (select 1 from private.sandbox_testers t where t.user_id = lower(s.user_id)))
    )
    or exists (
      select 1 from public.subscription_accounts a
      where a.user_id = p_user_id
        and a.original_transaction_id is null
        and a.revoked_at is null
        and (
          (a.status in ('trial', 'active', 'grace_period', 'billing_issue', 'promotional')
            and a.expires_at > now())
          or (a.status = 'promotional' and a.expires_at is null)
        )
        and (a.environment is null or upper(a.environment) = 'PRODUCTION'
             or exists (select 1 from private.sandbox_testers t where t.user_id = lower(a.user_id)))
    )
    or exists (
      select 1 from public.enterprise_access e
      where e.user_id = p_user_id and (e.granted_until is null or e.granted_until > now())
    )
  );
$$;

revoke all on function public.user_has_premium(text) from public, anon, authenticated;
grant execute on function public.user_has_premium(text) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Rate limits (Edge Functions only). Distinct from private.rate_limits
--    (daily quotas of the enterprise functions) and public.louane_rate_limits
--    (Louane daily quotas).
--
--    public.rate_limit_hit(bucket, subject, max, window): counts one hit and
--    returns true, or returns false without counting once `max` hits happened
--    in the window that started with the first hit.

create table if not exists private.rate_limit_windows (
  bucket text not null check (length(bucket) between 1 and 40),
  subject text not null check (length(subject) between 1 and 200),
  window_start timestamptz not null,
  count integer not null default 0 check (count >= 0),
  primary key (bucket, subject)
);
revoke all on private.rate_limit_windows from public, anon, authenticated;

create or replace function public.rate_limit_hit(p_bucket text, p_subject text, p_max integer, p_window_seconds integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  window_length interval;
  allowed boolean;
begin
  if p_bucket is null or p_subject is null or length(p_subject) = 0
     or p_max is null or p_max <= 0 or p_window_seconds is null or p_window_seconds <= 0 then
    return false;
  end if;
  window_length := make_interval(secs => p_window_seconds);
  insert into private.rate_limit_windows as r (bucket, subject, window_start, count)
  values (left(p_bucket, 40), left(p_subject, 200), now(), 1)
  on conflict (bucket, subject) do update set
    count = case when r.window_start > now() - window_length then r.count + 1 else 1 end,
    window_start = case when r.window_start > now() - window_length then r.window_start else now() end
  where r.window_start <= now() - window_length or r.count < p_max
  returning true into allowed;
  return coalesce(allowed, false);
end;
$$;

revoke all on function public.rate_limit_hit(text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.rate_limit_hit(text, text, integer, integer) to service_role;

-- Louane: one message in flight per account. The lock expires by itself after
-- 90 s (the function answers in < 35 s), so a crashed request never blocks
-- anyone; louane_rate_release() is called in a `finally`.
create table if not exists private.louane_inflight (
  user_id text primary key check (length(user_id) between 1 and 128),
  acquired_at timestamptz not null default now()
);
revoke all on private.louane_inflight from public, anon, authenticated;

create or replace function public.louane_rate_acquire(p_user_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  acquired boolean;
begin
  if p_user_id is null or length(p_user_id) = 0 then
    return false;
  end if;
  insert into private.louane_inflight as l (user_id, acquired_at)
  values (left(p_user_id, 128), now())
  on conflict (user_id) do update set acquired_at = now()
  where l.acquired_at < now() - interval '90 seconds'
  returning true into acquired;
  return coalesce(acquired, false);
end;
$$;

create or replace function public.louane_rate_release(p_user_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.louane_inflight where user_id = left(p_user_id, 128);
$$;

revoke all on function public.louane_rate_acquire(text) from public, anon, authenticated;
revoke all on function public.louane_rate_release(text) from public, anon, authenticated;
grant execute on function public.louane_rate_acquire(text) to service_role;
grant execute on function public.louane_rate_release(text) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Bounds on rows any account (anonymous included) can write.
--
--    analytics_events: the app inserts events in batches and ignores errors, so
--    an invalid row is dropped (BEFORE trigger returns null) rather than
--    failing the whole batch. Out-of-range device clocks are brought to now().

create or replace function private.analytics_events_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.event_name is null or new.event_name !~ '^[a-z][a-z0-9_]{1,63}$'
     or new.properties is null or jsonb_typeof(new.properties) <> 'object'
     or octet_length(new.properties::text) > 4096 then
    return null;
  end if;
  if new.occurred_at is null
     or new.occurred_at < now() - interval '7 days'
     or new.occurred_at > now() + interval '1 hour' then
    new.occurred_at := now();
  end if;
  return new;
end;
$$;

revoke execute on function private.analytics_events_guard() from public, anon, authenticated;

drop trigger if exists analytics_events_guard on public.analytics_events;
create trigger analytics_events_guard before insert on public.analytics_events
  for each row execute function private.analytics_events_guard();

-- practice_entries: entries are synced late (reinstall, other iPhone), so a
-- past date is legitimate; a future one is not. 4 h max per entry (a sleep
-- sound can run all night: it is clamped, not rejected).
create or replace function private.practice_entries_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.seconds := greatest(0, least(coalesce(new.seconds, 0), 14400));
  if new.occurred_at > now() + interval '1 hour' then
    new.occurred_at := now();
  end if;
  return new;
end;
$$;

revoke execute on function private.practice_entries_guard() from public, anon, authenticated;

drop trigger if exists practice_entries_guard on public.practice_entries;
create trigger practice_entries_guard before insert on public.practice_entries
  for each row execute function private.practice_entries_guard();

-- Free-form jsonb written by clients: 16 kB max (serialized). NOT VALID: the
-- rule applies to every new write without failing on an existing row.
alter table public.user_preferences drop constraint if exists user_preferences_raw_preferences_size;
alter table public.user_preferences add constraint user_preferences_raw_preferences_size
  check (octet_length(raw_preferences::text) <= 16384) not valid;
alter table public.programs drop constraint if exists programs_raw_program_size;
alter table public.programs add constraint programs_raw_program_size
  check (octet_length(raw_program::text) <= 16384) not valid;
alter table public.louane_memory drop constraint if exists louane_memory_memory_items_size;
alter table public.louane_memory add constraint louane_memory_memory_items_size
  check (octet_length(memory_items::text) <= 16384) not valid;

-- ---------------------------------------------------------------------------
-- 7. Table privileges.
--
--    practice_entries was created after the blanket revoke of the core
--    migration and inherited the default Supabase grants (anon included,
--    UPDATE, DELETE and TRUNCATE). The app only selects and inserts (upsert
--    with ignoreDuplicates); deletion is the account-data function (service
--    role, profile cascade).

revoke all on public.practice_entries from anon, authenticated;
grant select, insert on public.practice_entries to authenticated;

-- TRUNCATE ignores RLS; REFERENCES and TRIGGER are never needed by the API
-- roles. Applies to every current table of the public schema.
do $$
declare
  table_name text;
begin
  for table_name in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  loop
    execute format('revoke truncate, references, trigger on table public.%I from anon, authenticated', table_name);
  end loop;
end $$;

-- Future tables and sequences of the public schema (created by this role) are
-- no longer granted to anon/authenticated by default: every migration grants
-- what the app needs explicitly, as all of them already do. Functions keep the
-- PostgreSQL default (EXECUTE to PUBLIC): revoke it in each migration.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. Legacy account link. Same function as in
--    20261007091000_entreprise_supabase.sql, except that the subscription now
--    MOVES to the Supabase account instead of being copied (two accounts had
--    Premium for one purchase): the Firebase UID's store transactions are
--    rebound, and its imported projection row is moved.

create or replace function public.link_legacy_firebase_account(p_user_id text, p_apple_sub text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  legacy_uid text;
  legacy_row public.subscription_accounts%rowtype;
begin
  if p_user_id is null or p_apple_sub is null or length(p_apple_sub) = 0 then
    return null;
  end if;

  select u.firebase_uid into legacy_uid
  from migration.firebase_auth_users u
  where u.providers @> jsonb_build_array(jsonb_build_object('providerId', 'apple.com', 'uid', p_apple_sub))
    and not u.disabled
  order by u.exported_at desc
  limit 1;

  if legacy_uid is null then
    return null;
  end if;

  update public.profiles set firebase_uid = null
  where firebase_uid = legacy_uid and user_id <> p_user_id;
  update public.profiles set firebase_uid = legacy_uid where user_id = p_user_id;

  insert into public.enterprise_access (user_id, enterprise_id, firebase_enterprise_id, enterprise_name, granted_until, joined_at, raw_data)
  select p_user_id, e.enterprise_id, e.firebase_enterprise_id, e.enterprise_name, e.granted_until, e.joined_at, e.raw_data
  from public.enterprise_access e where e.user_id = legacy_uid
  on conflict (user_id) do nothing;

  -- One person, one seat: the Firebase UID no longer holds one once the
  -- Supabase account has it.
  delete from public.enterprise_access legacy
  where legacy.user_id = legacy_uid
    and legacy.enterprise_id is not null
    and legacy_uid <> p_user_id
    and exists (
      select 1 from public.enterprise_access mine
      where mine.user_id = p_user_id and mine.enterprise_id = legacy.enterprise_id
    );

  if legacy_uid = p_user_id then
    return legacy_uid;
  end if;

  -- Store transactions of the Firebase account (RevenueCat events) follow the
  -- person; later RevenueCat events resolve to p_user_id through firebase_uid.
  update private.store_subscriptions set user_id = p_user_id, updated_at = now()
  where user_id = legacy_uid;

  -- Subscriptions bought on Android or never claimed on this device: the
  -- active imported state moves (it is removed from the Firebase UID).
  select * into legacy_row from public.subscription_accounts
  where user_id = legacy_uid
    and revoked_at is null
    and (expires_at > now() or (status = 'promotional' and expires_at is null));
  if found then
    delete from public.subscription_accounts where user_id = legacy_uid;
    insert into public.subscription_accounts (
      user_id, original_transaction_id, entitlement_id, status, product_id, store, environment, period_type,
      expires_at, revoked_at, will_renew, source, source_updated_at, raw_customer_info
    ) values (
      p_user_id, legacy_row.original_transaction_id, legacy_row.entitlement_id, legacy_row.status,
      legacy_row.product_id, legacy_row.store, legacy_row.environment, legacy_row.period_type,
      legacy_row.expires_at, legacy_row.revoked_at, legacy_row.will_renew,
      case when legacy_row.original_transaction_id is null then 'migration' else legacy_row.source end,
      legacy_row.source_updated_at, legacy_row.raw_customer_info
    )
    on conflict (user_id) do nothing;
  end if;

  return legacy_uid;
end;
$$;

revoke all on function public.link_legacy_firebase_account(text, text) from public, anon, authenticated;
grant execute on function public.link_legacy_firebase_account(text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 9. Right to erasure (account-data DELETE), in one transaction.

create or replace function public.purge_user_data(p_user_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Supabase ids are UUIDs (Superwall may send them uppercase); Firebase UIDs
  -- are case-sensitive and compared exactly.
  is_uuid boolean := coalesce(p_user_id, '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  personal_keys text[] := array[
    'appAccountToken', 'originalAppUserId', 'app_user_id', 'original_app_user_id', 'aliases',
    'subscriber_attributes', 'transferred_from', 'transferred_to', 'userId', 'email'
  ];
begin
  if p_user_id is null or length(p_user_id) = 0 then
    return;
  end if;

  -- Subscription events have no foreign key, and an event not yet resolved to
  -- a user still names them in its payload.
  delete from public.subscription_events e
  where e.user_id = p_user_id
     or e.payload->'data'->>'originalAppUserId' = p_user_id
     or (is_uuid and lower(e.payload->'data'->>'originalAppUserId') = lower(p_user_id))
     or (is_uuid and lower(e.payload->'data'->>'appAccountToken') = lower(p_user_id))
     or e.payload->'event'->>'app_user_id' = p_user_id
     or e.payload->'event'->>'original_app_user_id' = p_user_id
     or coalesce(e.payload->'event'->'aliases', '[]'::jsonb) ? p_user_id;

  -- Store transactions stay (a later claim on the same Apple ID must still
  -- find them) but no longer point to the person.
  update private.store_subscriptions s set
    user_id = null,
    raw = coalesce(s.raw, '{}'::jsonb) - personal_keys,
    updated_at = now()
  where s.user_id = p_user_id
     or (is_uuid and lower(s.raw->>'appAccountToken') = lower(p_user_id))
     or (is_uuid and lower(s.raw->>'originalAppUserId') = lower(p_user_id))
     or s.raw->>'app_user_id' = p_user_id;

  delete from private.rate_limit_windows where subject = p_user_id;
  delete from private.louane_inflight where user_id = p_user_id;
  delete from private.sandbox_testers where user_id = lower(p_user_id);
  delete from public.louane_rate_limits where scope = 'user' and subject = p_user_id;

  -- Explicit for the largest tables; the profile delete cascades through every
  -- other user-owned table (preferences, progress, programs and steps, Louane
  -- conversations/messages/memory/counters/alerts, subscription_accounts,
  -- enterprise_access).
  delete from public.practice_entries where user_id = p_user_id;
  delete from public.analytics_events where user_id = p_user_id;
  delete from public.listening_events where user_id = p_user_id;
  delete from public.profiles where user_id = p_user_id;
end;
$$;

revoke all on function public.purge_user_data(text) from public, anon, authenticated;
grant execute on function public.purge_user_data(text) to service_role;

create or replace function public.purge_legacy_user(p_firebase_uid text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_firebase_uid is null or length(p_firebase_uid) = 0 then
    return;
  end if;
  perform public.purge_user_data(p_firebase_uid);
  delete from migration.firebase_documents
  where document_id = p_firebase_uid
     or position('/' || p_firebase_uid || '/' in '/' || collection_path || '/') > 0;
  delete from migration.firebase_auth_users where firebase_uid = p_firebase_uid;
  delete from migration.revenuecat_customers
  where app_user_id = p_firebase_uid or original_app_user_id = p_firebase_uid;
end;
$$;

revoke all on function public.purge_legacy_user(text) from public, anon, authenticated;
grant execute on function public.purge_legacy_user(text) to service_role;

-- ---------------------------------------------------------------------------
-- 10. Retention. Daily job:
--     analytics_events and listening_events > 13 months, subscription_events
--     > 24 months, anonymous accounts inactive for 6 months (no subscription,
--     no seat), plus the rate-limit housekeeping.
--     public.profiles has no foreign key to auth.users: the profile is deleted
--     first (cascade over the product tables), then the auth user (its own
--     auth.* rows cascade). If the auth delete fails, the profile is gone and
--     the auth user stays; the job logs a warning and carries on.

create or replace function private.purge_expired_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  analytics_deleted bigint := 0;
  listening_deleted bigint := 0;
  events_deleted bigint := 0;
  profiles_deleted bigint := 0;
  auth_deleted bigint := 0;
  stale_ids uuid[];
begin
  delete from public.analytics_events where occurred_at < now() - interval '13 months';
  get diagnostics analytics_deleted = row_count;

  delete from public.listening_events where occurred_at < now() - interval '13 months';
  get diagnostics listening_deleted = row_count;

  delete from public.subscription_events where coalesce(occurred_at, received_at) < now() - interval '24 months';
  get diagnostics events_deleted = row_count;

  delete from private.rate_limit_windows where window_start < now() - interval '1 day';
  delete from private.louane_inflight where acquired_at < now() - interval '1 day';
  if to_regprocedure('public.louane_purge_stale(interval)') is not null then
    perform public.louane_purge_stale();
  end if;

  begin
    -- last_sign_in_at does not move on token refresh: activity is read from
    -- the sessions and the product tables as well. 1 000 accounts per run.
    select array_agg(candidate.id) into stale_ids
    from (
      select u.id
      from auth.users u
      where u.is_anonymous
        and u.created_at < now() - interval '6 months'
        and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '6 months'
        and not exists (select 1 from auth.sessions s where s.user_id = u.id and coalesce(s.updated_at, s.created_at) >= now() - interval '6 months')
        and not exists (select 1 from public.profiles p where p.user_id = u.id::text and p.updated_at >= now() - interval '6 months')
        and not exists (select 1 from private.store_subscriptions s where s.user_id = u.id::text)
        and not exists (select 1 from public.subscription_accounts a where a.user_id = u.id::text)
        and not exists (select 1 from public.enterprise_access e where e.user_id = u.id::text)
        and not exists (select 1 from public.analytics_events x where x.user_id = u.id::text and x.occurred_at >= now() - interval '6 months')
        and not exists (select 1 from public.practice_entries x where x.user_id = u.id::text and x.received_at >= now() - interval '6 months')
        and not exists (select 1 from public.listening_events x where x.user_id = u.id::text and x.received_at >= now() - interval '6 months')
        and not exists (select 1 from public.louane_messages x where x.user_id = u.id::text and x.created_at >= now() - interval '6 months')
        and not exists (select 1 from public.session_progress x where x.user_id = u.id::text and x.updated_at >= now() - interval '6 months')
      order by u.created_at
      limit 1000
    ) candidate;

    if stale_ids is not null then
      delete from public.subscription_events where user_id = any (select id::text from unnest(stale_ids) id);
      delete from public.profiles where user_id = any (select id::text from unnest(stale_ids) id);
      get diagnostics profiles_deleted = row_count;
      begin
        delete from auth.users where id = any (stale_ids) and is_anonymous;
        get diagnostics auth_deleted = row_count;
      exception when others then
        raise warning 'purge_expired_data: auth.users delete failed: %', sqlerrm;
      end;
    end if;
  exception when others then
    raise warning 'purge_expired_data: anonymous accounts skipped: %', sqlerrm;
  end;

  return jsonb_build_object(
    'analytics_events', analytics_deleted,
    'listening_events', listening_deleted,
    'subscription_events', events_deleted,
    'anonymous_profiles', profiles_deleted,
    'anonymous_auth_users', auth_deleted
  );
end;
$$;

revoke all on function private.purge_expired_data() from public, anon, authenticated;

-- Daily at 03:17 UTC, only where pg_cron exists (hosted Supabase: enable it in
-- Database > Extensions if this block skipped it). Otherwise run
-- `select private.purge_expired_data();` from a scheduled job.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    begin
      create extension if not exists pg_cron;
      perform cron.schedule('quieto-purge-expired-data', '17 3 * * *', 'select private.purge_expired_data();');
    exception when others then
      raise warning 'pg_cron unavailable, retention job not scheduled: %', sqlerrm;
    end;
  end if;
end $$;
