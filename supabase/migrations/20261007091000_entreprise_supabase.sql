-- Quieto Entreprise (B2B) on Supabase: replaces the Firestore collections
-- `entreprises`, `entreprises/{id}/membres`, `acces_entreprise` and
-- `demandes_entreprise` used by the Firebase functions (backend/functions).
-- See supabase/functions/ENTREPRISE.md.
--
-- Membership reuses public.enterprise_access (one row per user = the old
-- `membres/{uid}` + `acces_entreprise/{uid}` pair): a seat is a row with
-- `enterprise_id`, and public.user_has_premium() already grants Premium while
-- `granted_until > now()`. No change to user_has_premium is needed.
-- All new tables are server-only: RLS on, no policy, service_role only.

-- ---------------------------------------------------------------------------
-- 1. Enterprises (Firestore `entreprises/{id}`).
--    id = Stripe subscription id (sub_…) or, for manual / legacy ones, the
--    Firestore document id.

create table public.enterprises (
  id text primary key check (length(id) between 1 and 128),
  name text not null check (length(name) between 1 and 120),
  name_locked boolean not null default false,          -- Firestore nomManuel
  code text not null check (length(code) between 1 and 40),
  code_key text not null unique check (code_key ~ '^[A-Z0-9]{1,24}$'),
  seats integer not null default 0 check (seats >= 0),
  paid_until timestamptz,                              -- Firestore finMs (0 → null)
  active boolean not null default false,
  stripe_status text,
  paid boolean,
  billing_email text,
  source text not null default 'stripe' check (source in ('stripe', 'manual')),
  stripe_customer_id text,
  manage_url text,
  invoice_url text,
  code_sent boolean not null default false,
  code_send_started_at timestamptz,
  legacy_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger enterprises_set_updated_at before update on public.enterprises
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Members: extend enterprise_access instead of a second table.

alter table public.enterprise_access
  add column enterprise_id text references public.enterprises(id) on delete cascade,
  add column joined_at timestamptz;

alter table public.enterprise_access alter column firebase_enterprise_id drop not null;
alter table public.enterprise_access
  add constraint enterprise_access_has_enterprise
    check (enterprise_id is not null or firebase_enterprise_id is not null),
  -- A null granted_until means "unlimited" in user_has_premium: never for a seat.
  add constraint enterprise_access_seat_has_end
    check (enterprise_id is null or granted_until is not null);

create index enterprise_access_enterprise_idx on public.enterprise_access(enterprise_id);

comment on table public.enterprise_access is
  'One enterprise seat per user (Premium offered by the employer). Written by the enterprise-access Edge Function only.';

-- ---------------------------------------------------------------------------
-- 3. Demo requests of the site (Firestore `demandes_entreprise`).

create table public.enterprise_demo_requests (
  id bigint generated always as identity primary key,
  profile text check (profile is null or length(profile) <= 60),
  first_name text not null check (length(first_name) between 1 and 60),
  last_name text not null check (length(last_name) between 1 and 60),
  email text not null check (length(email) between 3 and 120),
  company text not null check (length(company) between 1 and 100),
  phone text check (phone is null or length(phone) <= 30),
  company_size text check (company_size is null or length(company_size) <= 40),
  message text check (message is null or length(message) <= 2000),
  received_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. Daily rate limits (Firestore `quota_ip` / `quota_uid`), Paris day.

create table private.rate_limits (
  bucket text not null,
  subject text not null,
  day date not null,
  hits integer not null default 0,
  primary key (bucket, subject, day)
);

revoke all on private.rate_limits from public, anon, authenticated;

create or replace function public.consume_rate_limit(p_bucket text, p_subject text, p_limit integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Paris')::date;
  allowed boolean;
begin
  if p_limit is null or p_limit <= 0 then
    return false;
  end if;
  insert into private.rate_limits as r (bucket, subject, day, hits)
  values (left(p_bucket, 40), left(p_subject, 200), today, 1)
  on conflict (bucket, subject, day) do update set hits = r.hits + 1
    where r.hits < p_limit
  returning true into allowed;
  -- Occasional cleanup of past days.
  if random() < 0.01 then
    delete from private.rate_limits where day < today - 2;
  end if;
  return coalesce(allowed, false);
end;
$$;

revoke all on function public.consume_rate_limit(text, text, integer) from public, anon, authenticated;
grant execute on function public.consume_rate_limit(text, text, integer) to service_role;

-- ---------------------------------------------------------------------------
-- 5. Coverage: Premium until the end of the paid period + 10 days (time for
--    Stripe to retry a failed debit). null = the enterprise covers no one.

create or replace function private.enterprise_coverage(p_active boolean, p_paid_until timestamptz)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select case when p_active and p_paid_until is not null then p_paid_until + interval '10 days' end;
$$;

revoke all on function private.enterprise_coverage(boolean, timestamptz) from public, anon, authenticated;

-- Members follow renewals right away (Firebase extended them lazily at app
-- launch through synchroniserAbonnement). Like Firebase, access is only ever
-- EXTENDED: an enterprise that stops paying is simply not extended any more,
-- and what was granted stays until it ends.
create or replace function private.enterprise_propagate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cover timestamptz := private.enterprise_coverage(new.active, new.paid_until);
begin
  update public.enterprise_access a
  set granted_until = case when cover is not null and cover > a.granted_until then cover else a.granted_until end,
      enterprise_name = new.name
  where a.enterprise_id = new.id
    and ((cover is not null and cover > a.granted_until) or a.enterprise_name is distinct from new.name);
  return null;
end;
$$;

revoke all on function private.enterprise_propagate() from public, anon, authenticated;

create trigger enterprises_propagate_access
  after update of paid_until, active, name on public.enterprises
  for each row execute function private.enterprise_propagate();

-- ---------------------------------------------------------------------------
-- 6. Stripe → enterprise (webhook). Atomic upsert + reservation of the code
--    e-mail (two simultaneous webhooks must not both send it; the
--    reservation expires after 10 minutes if a send crashed).

create or replace function public.enterprise_apply_stripe(
  p_id text,
  p_name text,
  p_seats integer,
  p_status text,
  p_paid_until timestamptz,
  p_active boolean,
  p_paid boolean,
  p_email text,
  p_customer text,
  p_manage_url text,
  p_invoice_url text,
  p_new_code text,
  p_new_code_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  e public.enterprises%rowtype;
  send boolean;
begin
  if p_new_code is not null then
    insert into public.enterprises (id, name, code, code_key, seats, source)
    values (p_id, p_name, p_new_code, p_new_code_key, p_seats, 'stripe')
    on conflict (id) do nothing;
  end if;

  select * into e from public.enterprises where id = p_id for update;
  if not found then
    raise exception 'enterprise % not found and no code given', p_id;
  end if;

  send := coalesce(p_active, false) and not e.code_sent and coalesce(p_email, '') <> ''
    and (e.code_send_started_at is null or e.code_send_started_at < now() - interval '10 minutes');

  update public.enterprises set
    -- A name fixed by hand (name_locked) stays.
    name = case when e.name_locked then e.name else p_name end,
    seats = p_seats,
    stripe_status = p_status,
    paid_until = p_paid_until,
    active = coalesce(p_active, false),
    paid = p_paid,
    billing_email = p_email,
    stripe_customer_id = nullif(p_customer, ''),
    manage_url = nullif(p_manage_url, ''),
    invoice_url = coalesce(nullif(p_invoice_url, ''), e.invoice_url),
    source = 'stripe',
    code_send_started_at = case when send then now() else e.code_send_started_at end
  where id = p_id
  returning * into e;

  return jsonb_build_object(
    'send', send,
    'code', e.code,
    'name', e.name,
    'seats', e.seats,
    'email', e.billing_email,
    'manage_url', e.manage_url,
    'invoice_url', e.invoice_url
  );
end;
$$;

revoke all on function public.enterprise_apply_stripe(text, text, integer, text, timestamptz, boolean, boolean, text, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.enterprise_apply_stripe(text, text, integer, text, timestamptz, boolean, boolean, text, text, text, text, text, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 7. Employee activation by code. Preview (p_confirm = false) returns the
--    name; confirmation takes a seat (never above `seats`, the enterprise row
--    is locked so concurrent activations are serialised). Joining another
--    enterprise frees the previous seat (same row, new enterprise_id).
--    Result status: unknown | inactive | preview | full | joined.

create or replace function public.enterprise_join(p_user_id text, p_code_key text, p_confirm boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  e public.enterprises%rowtype;
  cover timestamptz;
  current_seat public.enterprise_access%rowtype;
  taken integer;
  granted timestamptz;
begin
  if p_user_id is null or p_code_key is null or length(p_code_key) < 6 then
    return jsonb_build_object('status', 'unknown');
  end if;

  if coalesce(p_confirm, false) then
    select * into e from public.enterprises where code_key = p_code_key for update;
  else
    select * into e from public.enterprises where code_key = p_code_key;
  end if;
  if not found then
    return jsonb_build_object('status', 'unknown');
  end if;

  cover := private.enterprise_coverage(e.active, e.paid_until);
  if cover is null or cover <= now() then
    return jsonb_build_object('status', 'inactive');
  end if;
  if not coalesce(p_confirm, false) then
    return jsonb_build_object('status', 'preview', 'name', e.name);
  end if;

  select * into current_seat from public.enterprise_access where user_id = p_user_id for update;
  if found and current_seat.enterprise_id = e.id then
    -- Already a member: grant again, without taking another seat.
    update public.enterprise_access
    set granted_until = greatest(granted_until, cover), enterprise_name = e.name
    where user_id = p_user_id
    returning granted_until into granted;
  else
    select count(*) into taken from public.enterprise_access where enterprise_id = e.id;
    if taken >= e.seats then
      return jsonb_build_object('status', 'full', 'name', e.name);
    end if;
    insert into public.enterprise_access as a
      (user_id, enterprise_id, firebase_enterprise_id, enterprise_name, granted_until, joined_at, raw_data)
    values (p_user_id, e.id, null, e.name, cover, now(), '{}'::jsonb)
    on conflict (user_id) do update set
      enterprise_id = excluded.enterprise_id,
      firebase_enterprise_id = null,
      enterprise_name = excluded.enterprise_name,
      -- What a previous employer already granted is kept (as with RevenueCat
      -- promotional grants), never shortened.
      granted_until = greatest(a.granted_until, excluded.granted_until),
      joined_at = excluded.joined_at,
      raw_data = '{}'::jsonb
    returning granted_until into granted;
  end if;

  return jsonb_build_object('status', 'joined', 'name', e.name, 'granted_until', granted);
end;
$$;

revoke all on function public.enterprise_join(text, text, boolean) from public, anon, authenticated;
grant execute on function public.enterprise_join(text, text, boolean) to service_role;

-- ---------------------------------------------------------------------------
-- 8. Legacy account link: the seat moves with the person. Same function as in
--    20261006120000_hard_paywall_superwall.sql, plus enterprise_id/joined_at,
--    and the Firebase UID's seat is released once copied.

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
-- 9. One-shot import from the Firestore snapshot already loaded by
--    backend/migration (migration.firebase_documents). Idempotent: run it
--    again after a fresh snapshot right before the cutover.
--    `select migration.import_firestore_enterprises();` (SQL editor / psql).

create or replace function migration.import_firestore_enterprises()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  enterprises_count integer;
  members_count integer;
  requests_count integer;
begin
  insert into public.enterprises as t (
    id, name, name_locked, code, code_key, seats, paid_until, active, stripe_status, paid,
    billing_email, source, stripe_customer_id, manage_url, invoice_url, code_sent, legacy_data, created_at
  )
  select
    d.document_id,
    left(coalesce(nullif(trim(d.raw_data->>'nom'), ''), 'Entreprise'), 120),
    coalesce(d.raw_data->>'nomManuel' = 'true', false),
    left(d.raw_data->>'code', 40),
    left(coalesce(nullif(d.raw_data->>'codeCle', ''), upper(regexp_replace(d.raw_data->>'code', '[^A-Za-z0-9]', '', 'g'))), 24),
    case when jsonb_typeof(d.raw_data->'places') = 'number' then greatest((d.raw_data->>'places')::numeric::integer, 0) else 0 end,
    case when jsonb_typeof(d.raw_data->'finMs') = 'number' and (d.raw_data->>'finMs')::numeric > 0
      then to_timestamp((d.raw_data->>'finMs')::numeric / 1000) end,
    coalesce(d.raw_data->>'actif' = 'true', false),
    d.raw_data->>'statut',
    case when jsonb_typeof(d.raw_data->'paye') = 'boolean' then (d.raw_data->>'paye')::boolean end,
    nullif(d.raw_data->>'email', ''),
    case when d.raw_data->>'source' = 'stripe' or (d.raw_data->>'source' is null and d.document_id like 'sub\_%')
      then 'stripe' else 'manual' end,
    nullif(d.raw_data->>'client', ''),
    nullif(d.raw_data->>'gererUrl', ''),
    nullif(d.raw_data->>'factureUrl', ''),
    coalesce(d.raw_data->>'codeEnvoye' = 'true', false),
    d.raw_data,
    coalesce(d.create_time, now())
  from migration.firebase_documents d
  where d.collection_path = 'entreprises'
    and coalesce(d.raw_data->>'code', '') <> ''
  on conflict (id) do update set
    name = excluded.name, name_locked = excluded.name_locked, code = excluded.code, code_key = excluded.code_key,
    seats = excluded.seats, paid_until = excluded.paid_until, active = excluded.active,
    stripe_status = excluded.stripe_status, paid = excluded.paid, billing_email = excluded.billing_email,
    source = excluded.source, stripe_customer_id = excluded.stripe_customer_id, manage_url = excluded.manage_url,
    invoice_url = excluded.invoice_url, code_sent = excluded.code_sent, legacy_data = excluded.legacy_data;
  get diagnostics enterprises_count = row_count;

  -- entreprises/{id}/membres/{uid}: uid = Firebase UID (profiles imported by
  -- backend/migration/import.mjs). link_legacy_firebase_account() moves the
  -- seat to the Supabase account when the person signs in with Apple.
  insert into public.enterprise_access as a
    (user_id, enterprise_id, firebase_enterprise_id, enterprise_name, granted_until, joined_at, raw_data)
  select
    m.document_id,
    e.id,
    e.id,
    e.name,
    coalesce(greatest(
      case when jsonb_typeof(m.raw_data->'finAccordeeMs') = 'number' and (m.raw_data->>'finAccordeeMs')::numeric > 0
        then to_timestamp((m.raw_data->>'finAccordeeMs')::numeric / 1000) end,
      private.enterprise_coverage(e.active, e.paid_until)
    ), now()),
    case when m.raw_data->'depuis'->>'__type' = 'timestamp' then (m.raw_data->'depuis'->>'value')::timestamptz end,
    m.raw_data
  from migration.firebase_documents m
  join public.enterprises e on m.collection_path = 'entreprises/' || e.id || '/membres'
  where exists (select 1 from public.profiles p where p.user_id = m.document_id)
  on conflict (user_id) do update set
    enterprise_id = excluded.enterprise_id,
    firebase_enterprise_id = excluded.firebase_enterprise_id,
    enterprise_name = excluded.enterprise_name,
    granted_until = greatest(a.granted_until, excluded.granted_until),
    joined_at = coalesce(a.joined_at, excluded.joined_at),
    raw_data = excluded.raw_data;
  get diagnostics members_count = row_count;

  insert into public.enterprise_demo_requests
    (profile, first_name, last_name, email, company, phone, company_size, message, received_at)
  select
    left(nullif(d.raw_data->>'profil', ''), 60),
    left(coalesce(nullif(d.raw_data->>'prenom', ''), '?'), 60),
    left(coalesce(nullif(d.raw_data->>'nom', ''), '?'), 60),
    left(coalesce(nullif(d.raw_data->>'email', ''), '?@?'), 120),
    left(coalesce(nullif(d.raw_data->>'entreprise', ''), '?'), 100),
    left(nullif(d.raw_data->>'telephone', ''), 30),
    left(nullif(d.raw_data->>'taille', ''), 40),
    left(nullif(d.raw_data->>'message', ''), 2000),
    coalesce(
      case when d.raw_data->'recueLe'->>'__type' = 'timestamp' then (d.raw_data->'recueLe'->>'value')::timestamptz end,
      d.create_time, now())
  from migration.firebase_documents d
  where d.collection_path = 'demandes_entreprise'
    and not exists (
      select 1 from public.enterprise_demo_requests r
      where r.email = left(coalesce(nullif(d.raw_data->>'email', ''), '?@?'), 120)
        and r.received_at = coalesce(
          case when d.raw_data->'recueLe'->>'__type' = 'timestamp' then (d.raw_data->'recueLe'->>'value')::timestamptz end,
          d.create_time, now())
    );
  get diagnostics requests_count = row_count;

  return jsonb_build_object('enterprises', enterprises_count, 'members', members_count, 'demo_requests', requests_count);
end;
$$;

revoke all on function migration.import_firestore_enterprises() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10. Privileges: server only.

alter table public.enterprises enable row level security;
alter table public.enterprise_demo_requests enable row level security;

revoke all on public.enterprises, public.enterprise_demo_requests from public, anon, authenticated;
grant select, insert, update, delete on public.enterprises, public.enterprise_demo_requests to service_role;
grant select, insert, update, delete on public.enterprise_access to service_role;

comment on table public.enterprises is 'Quieto Entreprise customers (Stripe or manual). Server only (service_role).';
comment on table public.enterprise_demo_requests is 'Demo requests from the Quieto Entreprise site. Server only (service_role).';
