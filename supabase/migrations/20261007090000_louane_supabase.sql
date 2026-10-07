-- Louane on a Supabase Edge Function (supabase/functions/louane): the
-- Firestore collections the Firebase `louane` function used become tables.
--   compteurs/{uid}   -> public.louane_usage_counters  (messages: total + Paris day)
--   quota_ip/quota_uid -> public.louane_rate_limits    (daily quotas per hashed IP / account)
--   securite/{uid}    -> public.louane_safety_alerts   (3114 message: once per 24 h)
--   vigie_louane      -> public.louane_stats           (anonymous product stats, never text)
-- Conversations, messages and memory already live in louane_conversations,
-- louane_messages and louane_memory (20261005170000_quieto_core.sql).
-- All four tables are server-only: RLS on with no policy, no grant to anon or
-- authenticated, service_role only (the Edge Function).

create table public.louane_usage_counters (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  total integer not null default 0 check (total >= 0),
  day date not null default ((now() at time zone 'Europe/Paris')::date),
  day_count integer not null default 0 check (day_count >= 0),
  updated_at timestamptz not null default now()
);

create table public.louane_rate_limits (
  scope text not null check (scope in ('ip', 'user')),
  subject text not null check (length(subject) between 1 and 200),
  field text not null check (field ~ '^[a-z_]{1,40}$'),
  day date not null,
  count integer not null default 0 check (count >= 0),
  primary key (scope, subject, field)
);

create table public.louane_safety_alerts (
  user_id text primary key references public.profiles(user_id) on delete cascade,
  alerted_at timestamptz not null default now()
);

create table public.louane_stats (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  niveau smallint check (niveau between 0 and 2),
  categorie text,
  paywall boolean not null default false,
  plafond boolean not null default false,
  details jsonb not null default '{}'::jsonb
);

create index louane_stats_created_idx on public.louane_stats(created_at);
create index louane_rate_limits_day_idx on public.louane_rate_limits(day);

alter table public.louane_usage_counters enable row level security;
alter table public.louane_rate_limits enable row level security;
alter table public.louane_safety_alerts enable row level security;
alter table public.louane_stats enable row level security;

revoke all on public.louane_usage_counters, public.louane_rate_limits,
  public.louane_safety_alerts, public.louane_stats from public, anon, authenticated;
grant select, insert, update, delete on public.louane_usage_counters, public.louane_rate_limits,
  public.louane_safety_alerts, public.louane_stats to service_role;

comment on table public.louane_usage_counters is 'Louane messages answered per account: total and Paris day. Edge Function only.';
comment on table public.louane_rate_limits is 'Louane daily quotas (hashed IP or account). Edge Function only.';
comment on table public.louane_safety_alerts is 'Last time the 3114 safety message was shown to an account. Edge Function only.';
comment on table public.louane_stats is 'Anonymous Louane product stats (levels, counters, never message text nor name). Edge Function only.';

-- Counters of an account for the current Paris day (zeros if none yet).
create or replace function public.louane_read_counters(p_user_id text)
returns table (total integer, day_count integer)
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(max(c.total), 0)::integer,
         coalesce(max(case when c.day = (now() at time zone 'Europe/Paris')::date then c.day_count end), 0)::integer
  from public.louane_usage_counters c
  where c.user_id = p_user_id;
$$;

-- One answered message: atomic, re-read at write time (no lost increment).
create or replace function public.louane_increment_counters(p_user_id text)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into public.louane_usage_counters as c (user_id, total, day, day_count, updated_at)
  values (p_user_id, 1, (now() at time zone 'Europe/Paris')::date, 1, now())
  on conflict (user_id) do update set
    total = c.total + 1,
    day_count = case when c.day = excluded.day then c.day_count + 1 else 1 end,
    day = excluded.day,
    updated_at = now();
$$;

-- Daily quota: counts p_weight and returns true, or returns false without
-- counting when the limit would be exceeded. A new Paris day starts at zero.
create or replace function public.louane_rate_limit_hit(
  p_scope text, p_subject text, p_field text, p_limit integer, p_weight integer default 1
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Paris')::date;
begin
  if p_weight > p_limit then
    return false;
  end if;
  insert into public.louane_rate_limits as r (scope, subject, field, day, count)
  values (p_scope, left(p_subject, 200), p_field, today, p_weight)
  on conflict (scope, subject, field) do update set
    count = case when r.day = excluded.day then r.count + p_weight else p_weight end,
    day = excluded.day
  where r.day <> excluded.day or r.count + p_weight <= p_limit;
  return found;
end;
$$;

-- Housekeeping for a scheduled job (pg_cron), not called by the function.
create or replace function public.louane_purge_stale(p_stats_retention interval default interval '180 days')
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.louane_rate_limits where day < (now() at time zone 'Europe/Paris')::date - 1;
  delete from public.louane_stats where created_at < now() - p_stats_retention;
$$;

revoke all on function public.louane_read_counters(text) from public, anon, authenticated;
revoke all on function public.louane_increment_counters(text) from public, anon, authenticated;
revoke all on function public.louane_rate_limit_hit(text, text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.louane_purge_stale(interval) from public, anon, authenticated;
grant execute on function public.louane_read_counters(text) to service_role;
grant execute on function public.louane_increment_counters(text) to service_role;
grant execute on function public.louane_rate_limit_hit(text, text, text, integer, integer) to service_role;
grant execute on function public.louane_purge_stale(interval) to service_role;
