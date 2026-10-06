-- Hard paywall + Superwall (StoreKit 2) entitlements.
--
-- * Every session, every audio file and Louane require an active entitlement.
-- * Entitlements are keyed by the App Store original transaction id, so a
--   subscription survives a reinstall, a new anonymous account or the move
--   from the Flutter app (Firebase UID) to the native app (Supabase UUID).
-- * Writes only come from Edge Functions (service role) through
--   public.apply_store_subscription(), which is ordered and atomic.
-- * RevenueCat history stays readable; RevenueCat events go through the same
--   function until the legacy app is retired.

-- ---------------------------------------------------------------------------
-- 1. Profiles: clients may only edit cosmetic columns. `firebase_uid` is set by
--    the server after a proven Apple identity match; `is_anonymous` mirrors the
--    JWT.

revoke insert, update on public.profiles from authenticated;
grant insert (user_id, first_name, locale, onboarding_completed_at) on public.profiles to authenticated;
-- user_id is listed because PostgREST upserts rewrite every sent column; RLS
-- (user_id = sub) keeps it pinned to the caller.
grant update (user_id, first_name, locale, onboarding_completed_at) on public.profiles to authenticated;

create or replace function private.profiles_sync_identity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.jwt()) is not null and (select auth.jwt()->>'role') = 'authenticated' then
    new.is_anonymous := coalesce(
      (select (auth.jwt()->>'is_anonymous')::boolean),
      (select auth.jwt()->'firebase'->>'sign_in_provider') = 'anonymous',
      false
    );
    if tg_op = 'UPDATE' then
      new.firebase_uid := old.firebase_uid;
    else
      new.firebase_uid := null;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.profiles_sync_identity() from public, anon, authenticated;

create trigger profiles_sync_identity before insert or update on public.profiles
  for each row execute function private.profiles_sync_identity();

-- ---------------------------------------------------------------------------
-- 2. analytics_events was created after the blanket revoke and inherited the
--    default Supabase grants (including TRUNCATE).

revoke all on public.analytics_events from anon, authenticated;
grant select, insert on public.analytics_events to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Louane messages: no client-forged system prompts, and updates must stay in
--    a conversation the user owns.

drop policy messages_insert_own on public.louane_messages;
drop policy messages_update_own on public.louane_messages;

create policy messages_insert_own on public.louane_messages for insert to authenticated with check (
  user_id = (select auth.jwt()->>'sub')
  and role in ('user', 'assistant')
  and exists (
    select 1 from public.louane_conversations c
    where c.id = conversation_id and c.user_id = (select auth.jwt()->>'sub')
  )
);
create policy messages_update_own on public.louane_messages for update to authenticated
  using (user_id = (select auth.jwt()->>'sub'))
  with check (
    user_id = (select auth.jwt()->>'sub')
    and role in ('user', 'assistant')
    and exists (
      select 1 from public.louane_conversations c
      where c.id = conversation_id and c.user_id = (select auth.jwt()->>'sub')
    )
  );

-- ---------------------------------------------------------------------------
-- 4. Store subscriptions registry (server only) and per-user projection.

alter table public.subscription_accounts
  add column original_transaction_id text unique,
  add column period_type text,
  add column revoked_at timestamptz;

alter table public.subscription_accounts drop constraint if exists subscription_accounts_status_check;
alter table public.subscription_accounts add constraint subscription_accounts_status_check
  check (status in ('unknown', 'inactive', 'trial', 'active', 'grace_period', 'billing_issue', 'expired', 'revoked', 'promotional'));

create table private.store_subscriptions (
  original_transaction_id text primary key,
  user_id text references public.profiles(user_id) on delete set null,
  product_id text,
  store text,
  environment text,
  status text not null,
  period_type text,
  expires_at timestamptz,
  revoked_at timestamptz,
  will_renew boolean,
  source text not null,
  last_event_at timestamptz not null,
  raw jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index store_subscriptions_user_idx on private.store_subscriptions(user_id);
revoke all on private.store_subscriptions from public, anon, authenticated;

-- Single writer for entitlements. `p_transfer` is only true for a StoreKit
-- transaction verified on the claimant's own device (same behaviour as the
-- RevenueCat "transfer" default): the subscription follows the Apple ID.
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
  p_raw jsonb
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
    target_user := p_user_id;
  elsif current_row.user_id is not null then
    target_user := current_row.user_id;
  elsif candidate_exists then
    target_user := p_user_id;
  else
    target_user := null;
  end if;

  -- An older event never overwrites a newer state (RevenueCat/Superwall retries,
  -- re-imports). The binding can still move on a verified device claim.
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
    update private.store_subscriptions set user_id = target_user, updated_at = now()
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

revoke all on function public.apply_store_subscription(text, text, boolean, text, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz, jsonb) from public, anon, authenticated;
grant execute on function public.apply_store_subscription(text, text, boolean, text, text, text, text, text, text, timestamptz, timestamptz, boolean, timestamptz, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Entitlement check (hard paywall). A billing issue keeps access only until
--    the paid period ends; Apple extends `expires_at` during the grace period.

create or replace function public.user_has_premium(p_user_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and (
    exists (
      select 1 from public.subscription_accounts s
      where s.user_id = p_user_id
        and s.revoked_at is null
        and (
          (s.status in ('trial', 'active', 'grace_period', 'billing_issue', 'promotional')
            and s.expires_at > now())
          or (s.status = 'promotional' and s.expires_at is null)
        )
    )
    or exists (
      select 1 from public.enterprise_access e
      where e.user_id = p_user_id and (e.granted_until is null or e.granted_until > now())
    )
  );
$$;

revoke all on function public.user_has_premium(text) from public, anon, authenticated;
grant execute on function public.user_has_premium(text) to service_role;

create or replace function public.has_premium_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.user_has_premium((select auth.jwt()->>'sub'));
$$;

revoke all on function public.has_premium_access() from public, anon;
grant execute on function public.has_premium_access() to authenticated;

-- Hard paywall on audio: no free tracks any more.
drop policy premium_audio_read on storage.objects;
create policy premium_audio_read on storage.objects for select to authenticated using (
  bucket_id = 'session-audio' and (select public.has_premium_access())
);

update public.sessions set is_premium = true where is_premium = false;
alter table public.sessions alter column is_premium set default true;

-- ---------------------------------------------------------------------------
-- 6. Legacy account link: a Supabase user signed in with Apple inherits the
--    Firebase account that used the same Apple identity (same developer team,
--    so the same Apple `sub`). Server only.

create or replace function public.link_legacy_firebase_account(p_user_id text, p_apple_sub text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  legacy_uid text;
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

  insert into public.enterprise_access (user_id, firebase_enterprise_id, enterprise_name, granted_until, raw_data)
  select p_user_id, e.firebase_enterprise_id, e.enterprise_name, e.granted_until, e.raw_data
  from public.enterprise_access e where e.user_id = legacy_uid
  on conflict (user_id) do nothing;

  -- Subscriptions bought on Android or never claimed on this device: keep the
  -- imported RevenueCat state until it expires.
  insert into public.subscription_accounts (
    user_id, entitlement_id, status, product_id, store, environment, period_type, expires_at,
    revoked_at, will_renew, source, source_updated_at, raw_customer_info
  )
  select p_user_id, s.entitlement_id, s.status, s.product_id, s.store, s.environment, s.period_type,
    s.expires_at, s.revoked_at, s.will_renew, 'migration', s.source_updated_at, s.raw_customer_info
  from public.subscription_accounts s
  where s.user_id = legacy_uid and s.expires_at > now()
  on conflict (user_id) do nothing;

  return legacy_uid;
end;
$$;

revoke all on function public.link_legacy_firebase_account(text, text) from public, anon, authenticated;
grant execute on function public.link_legacy_firebase_account(text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 7. Right to erasure for imported Firebase/RevenueCat evidence.

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
  delete from public.subscription_events where user_id = p_firebase_uid;
  delete from public.profiles where user_id = p_firebase_uid;
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
