-- Analytics dashboard (dashboard/). Read-only aggregates for the Quieto team.
--
-- The raw tables keep their per-user RLS: the dashboard never reads a row,
-- it only calls the `dashboard_*` functions below. Each one first checks that
-- the caller signed in with an email listed in `private.dashboard_admins`.
-- Grant access from the SQL editor (service role):
--   insert into private.dashboard_admins (email) values ('someone@example.com');
--
-- Activity = any analytics event or practice entry. Days are bucketed in
-- `p_tz` (Europe/Paris by default).

create table private.dashboard_admins (
  email text primary key check (email = lower(email) and position('@' in email) > 1),
  added_at timestamptz not null default now()
);
revoke all on private.dashboard_admins from public, anon, authenticated;

create or replace function public.is_dashboard_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false
     and exists (
       select 1 from private.dashboard_admins a
       where a.email = lower(coalesce(auth.jwt()->>'email', ''))
     );
$$;

revoke all on function public.is_dashboard_admin() from public, anon;
grant execute on function public.is_dashboard_admin() to authenticated;

create or replace function private.assert_dashboard_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_dashboard_admin() then
    raise exception 'dashboard_access_denied' using errcode = '42501';
  end if;
end;
$$;

-- The iOS app sends every property as a string.
create or replace function private.num(value text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when value ~ '^-?[0-9]+(\.[0-9]+)?$' then value::numeric end;
$$;

create or replace function private.user_activity()
returns table (user_id text, occurred_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select e.user_id, e.occurred_at from public.analytics_events e
  union all
  select p.user_id, p.occurred_at from public.practice_entries p;
$$;

revoke all on function private.assert_dashboard_admin() from public, anon, authenticated;
revoke all on function private.num(text) from public, anon, authenticated;
revoke all on function private.user_activity() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Headline numbers for a period, plus the live subscription state.

create or replace function public.dashboard_overview(p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.assert_dashboard_admin();

  with events as (
    select * from public.analytics_events
    where occurred_at >= p_from and occurred_at < p_to
  ),
  activity as (
    select * from private.user_activity()
    where occurred_at >= p_to - interval '30 days' and occurred_at < p_to
  ),
  completed as (
    select
      count(distinct user_id) as users,
      percentile_cont(0.5) within group (order by private.num(properties->>'active_seconds')) as active_median,
      percentile_cont(0.5) within group (order by private.num(properties->>'duration_seconds')) as duration_median
    from events where event_name = 'onboarding_completed'
  ),
  practice as (
    select count(*) as entries, count(distinct user_id) as users, coalesce(sum(seconds), 0) as seconds
    from public.practice_entries
    where occurred_at >= p_from and occurred_at < p_to
  ),
  store as (
    select
      count(*) filter (where e.event_type = 'initial_purchase' and upper(e.payload->'data'->>'periodType') = 'TRIAL') as trials,
      count(*) filter (where e.event_type = 'initial_purchase' and upper(coalesce(e.payload->'data'->>'periodType', '')) <> 'TRIAL') as direct_purchases,
      count(*) filter (where e.event_type = 'renewal' and e.payload->'data'->>'isTrialConversion' = 'true') as trial_conversions,
      count(*) filter (where e.event_type = 'renewal') as renewals,
      count(*) filter (where e.event_type = 'cancellation') as cancellations,
      count(*) filter (where e.event_type = 'billing_issue') as billing_issues,
      coalesce(sum(private.num(e.payload->'data'->>'proceeds')), 0) as proceeds
    from public.subscription_events e
    where e.source = 'superwall' and e.occurred_at >= p_from and e.occurred_at < p_to
      -- Sandbox purchases (TestFlight, StoreKit testing) are not business.
      and upper(coalesce(e.payload->'data'->>'environment', 'PRODUCTION')) = 'PRODUCTION'
  ),
  access as (
    select
      count(*) filter (where s.status = 'trial') as trialing,
      count(*) filter (where s.status in ('active', 'grace_period', 'billing_issue')) as paying,
      count(*) filter (where s.status = 'promotional') as promotional,
      count(*) filter (where s.will_renew is false) as not_renewing
    from public.subscription_accounts s
    where s.revoked_at is null and s.expires_at > now()
  )
  select jsonb_build_object(
    'new_users', (select count(*) from public.profiles where created_at >= p_from and created_at < p_to),
    'onboarding_started', (select count(distinct user_id) from events where event_name = 'onboarding_started'),
    'onboarding_completed', (select users from completed),
    'onboarding_active_seconds_median', (select active_median from completed),
    'onboarding_duration_seconds_median', (select duration_median from completed),
    'paywall_viewers', (select count(distinct user_id) from events where event_name = 'paywall_viewed'),
    'trial_starters', (select count(distinct user_id) from events where event_name = 'trial_started'),
    'dau', (select count(distinct user_id) from activity where occurred_at >= p_to - interval '1 day'),
    'wau', (select count(distinct user_id) from activity where occurred_at >= p_to - interval '7 days'),
    'mau', (select count(distinct user_id) from activity),
    'practice_entries', (select entries from practice),
    'practice_users', (select users from practice),
    'practice_minutes', (select round(seconds / 60.0) from practice),
    'store', (select to_jsonb(store) from store),
    'access', (select to_jsonb(access) from access)
      || jsonb_build_object('enterprise', (
        select count(*) from public.enterprise_access e
        where e.granted_until is null or e.granted_until > now()
      ))
  ) into result;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- One row per day of the period.

create or replace function public.dashboard_daily(p_from timestamptz, p_to timestamptz, p_tz text default 'Europe/Paris')
returns table (
  day date,
  new_users bigint,
  active_users bigint,
  onboarding_completed bigint,
  trial_starters bigint,
  practice_minutes numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_dashboard_admin();
  return query
  with days as (
    select generate_series((p_from at time zone p_tz)::date, ((p_to - interval '1 second') at time zone p_tz)::date, interval '1 day')::date as day
  ),
  activity as (
    select distinct a.user_id, (a.occurred_at at time zone p_tz)::date as day
    from private.user_activity() a
    where a.occurred_at >= p_from and a.occurred_at < p_to
  ),
  events as (
    select e.user_id, e.event_name, (e.occurred_at at time zone p_tz)::date as day
    from public.analytics_events e
    where e.occurred_at >= p_from and e.occurred_at < p_to
      and e.event_name in ('onboarding_completed', 'trial_started')
  )
  select
    d.day,
    (select count(*) from public.profiles p where (p.created_at at time zone p_tz)::date = d.day),
    (select count(*) from activity a where a.day = d.day),
    (select count(distinct e.user_id) from events e where e.day = d.day and e.event_name = 'onboarding_completed'),
    (select count(distinct e.user_id) from events e where e.day = d.day and e.event_name = 'trial_started'),
    (select round(coalesce(sum(pe.seconds), 0) / 60.0) from public.practice_entries pe
      where (pe.occurred_at at time zone p_tz)::date = d.day)
  from days d
  order by d.day;
end;
$$;

-- ---------------------------------------------------------------------------
-- Onboarding funnel for the people who started it during the period: how many
-- reached each screen, and the median time they spent on it.

create or replace function public.dashboard_onboarding(p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.assert_dashboard_admin();

  with cohort as (
    select e.user_id, min(e.occurred_at) as started_at
    from public.analytics_events e
    where e.event_name = 'onboarding_started' and e.occurred_at >= p_from and e.occurred_at < p_to
    group by e.user_id
  ),
  steps as (
    select e.user_id, e.properties
    from public.analytics_events e
    join cohort c on c.user_id = e.user_id
    where e.event_name = 'onboarding_step' and e.occurred_at >= c.started_at
  ),
  reached as (
    select
      s.properties->>'step' as step,
      max(private.num(s.properties->>'act')) as act,
      percentile_cont(0.5) within group (order by private.num(s.properties->>'index')) as position,
      count(distinct s.user_id) as users
    from steps s
    where s.properties->>'step' is not null
    group by 1
  ),
  timing as (
    select
      s.properties->>'previous_step' as step,
      percentile_cont(0.5) within group (order by private.num(s.properties->>'previous_step_seconds')) as median_seconds
    from steps s
    where s.properties->>'direction' = 'forward'
    group by 1
  ),
  finished as (
    select count(distinct e.user_id) as users
    from public.analytics_events e
    join cohort c on c.user_id = e.user_id
    where e.event_name = 'onboarding_completed' and e.occurred_at >= c.started_at
  )
  select jsonb_build_object(
    'started', (select count(*) from cohort),
    'completed', (select users from finished),
    'steps', coalesce((
      select jsonb_agg(jsonb_build_object(
        'step', r.step, 'act', r.act, 'position', r.position, 'users', r.users, 'median_seconds', t.median_seconds
      ) order by r.position, r.step)
      from reached r left join timing t on t.step = r.step
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Retention. Weekly cohorts by sign-up week (share of the cohort active in
-- each following week) and classic day-N retention over the last 90 days.

create or replace function public.dashboard_retention(p_weeks integer default 8, p_tz text default 'Europe/Paris')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
  weeks integer := least(greatest(p_weeks, 1), 26);
  first_week date := date_trunc('week', (now() at time zone p_tz))::date - (weeks - 1) * 7;
begin
  perform private.assert_dashboard_admin();

  with users as (
    select p.user_id, p.created_at,
           date_trunc('week', (p.created_at at time zone p_tz))::date as cohort_week
    from public.profiles p
    where p.created_at >= now() - interval '90 days'
       or (p.created_at at time zone p_tz)::date >= first_week
  ),
  activity as (
    select distinct a.user_id,
           u.cohort_week,
           ((date_trunc('week', (a.occurred_at at time zone p_tz))::date - u.cohort_week) / 7) as week_offset,
           floor(extract(epoch from (a.occurred_at - u.created_at)) / 86400)::integer as day_offset
    from private.user_activity() a
    join users u on u.user_id = a.user_id
    where a.occurred_at >= u.created_at
  ),
  cohorts as (
    select u.cohort_week, count(*) as size
    from users u
    where u.cohort_week >= first_week
    group by 1
  ),
  cells as (
    select a.cohort_week, a.week_offset, count(distinct a.user_id) as users
    from activity a
    where a.cohort_week >= first_week
    group by 1, 2
  ),
  day_n as (
    select n,
           (select count(*) from users u where u.created_at <= now() - make_interval(days => n + 1)) as eligible,
           (select count(distinct a.user_id) from activity a join users u on u.user_id = a.user_id
             where a.day_offset = n and u.created_at <= now() - make_interval(days => n + 1)) as retained
    from unnest(array[1, 7, 30]) as n
  )
  select jsonb_build_object(
    'cohorts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'week', c.cohort_week,
        'size', c.size,
        'weeks', (
          select coalesce(jsonb_agg(coalesce(cell.users, 0) order by w), '[]'::jsonb)
          from generate_series(0, (date_trunc('week', (now() at time zone p_tz))::date - c.cohort_week) / 7) as w
          left join cells cell on cell.cohort_week = c.cohort_week and cell.week_offset = w
        )
      ) order by c.cohort_week)
      from cohorts c
    ), '[]'::jsonb),
    'day_n', (select jsonb_agg(jsonb_build_object('day', n, 'eligible', eligible, 'retained', retained) order by n) from day_n)
  ) into result;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Product usage for the period: what people actually do.

create or replace function public.dashboard_usage(p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.assert_dashboard_admin();

  select jsonb_build_object(
    'by_kind', coalesce((
      select jsonb_agg(jsonb_build_object('kind', kind, 'entries', entries, 'users', users, 'minutes', minutes) order by entries desc)
      from (
        select p.kind, count(*) as entries, count(distinct p.user_id) as users, round(sum(p.seconds) / 60.0) as minutes
        from public.practice_entries p
        where p.occurred_at >= p_from and p.occurred_at < p_to
        group by p.kind
      ) k
    ), '[]'::jsonb),
    'top_content', coalesce((
      select jsonb_agg(jsonb_build_object('content', t.content_id, 'title', s.title->>'fr', 'kind', t.kind, 'entries', t.entries, 'users', t.users) order by t.entries desc)
      from (
        select p.content_id, p.kind, count(*) as entries, count(distinct p.user_id) as users
        from public.practice_entries p
        where p.occurred_at >= p_from and p.occurred_at < p_to and p.kind <> 'check_in'
        group by p.content_id, p.kind
        order by entries desc
        limit 10
      ) t
      left join public.sessions s on s.id = t.content_id
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object('event', event_name, 'count', total, 'users', users) order by total desc)
      from (
        select e.event_name, count(*) as total, count(distinct e.user_id) as users
        from public.analytics_events e
        where e.occurred_at >= p_from and e.occurred_at < p_to
        group by e.event_name
      ) ev
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.dashboard_overview(timestamptz, timestamptz) from public, anon;
revoke all on function public.dashboard_daily(timestamptz, timestamptz, text) from public, anon;
revoke all on function public.dashboard_onboarding(timestamptz, timestamptz) from public, anon;
revoke all on function public.dashboard_retention(integer, text) from public, anon;
revoke all on function public.dashboard_usage(timestamptz, timestamptz) from public, anon;
grant execute on function public.dashboard_overview(timestamptz, timestamptz) to authenticated;
grant execute on function public.dashboard_daily(timestamptz, timestamptz, text) to authenticated;
grant execute on function public.dashboard_onboarding(timestamptz, timestamptz) to authenticated;
grant execute on function public.dashboard_retention(integer, text) to authenticated;
grant execute on function public.dashboard_usage(timestamptz, timestamptz) to authenticated;

-- Funnel and retention scan analytics events by name and time.
create index if not exists analytics_events_name_time_idx on public.analytics_events (event_name, occurred_at);
create index if not exists profiles_created_at_idx on public.profiles (created_at);
create index if not exists practice_entries_time_idx on public.practice_entries (occurred_at);
