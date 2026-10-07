-- Goal plans (decision of 6 October 2026): six plans of 28 days, an optional
-- discovery week before, a rhythm that spaces the days and a short variant.
-- The app keeps the plan on the iPhone and copies it here; one active plan per
-- person (programs_one_active_per_user_idx), the previous one becomes
-- 'abandoned' when the person changes plan.

alter table public.programs
  add column if not exists plan_id text,
  add column if not exists plan_version smallint,
  add column if not exists rhythm text,
  add column if not exists variant text,
  add column if not exists includes_discovery boolean not null default false;

alter table public.programs drop constraint if exists programs_plan_id_check;
alter table public.programs add constraint programs_plan_id_check
  check (plan_id is null or plan_id in ('sleep', 'anxiety', 'stress', 'mind', 'self', 'relationships'));
alter table public.programs drop constraint if exists programs_plan_version_check;
alter table public.programs add constraint programs_plan_version_check
  check (plan_version is null or plan_version between 1 and 100);
alter table public.programs drop constraint if exists programs_rhythm_check;
alter table public.programs add constraint programs_rhythm_check
  check (rhythm is null or rhythm in ('Doux', 'Régulier', 'Soutenu'));
alter table public.programs drop constraint if exists programs_variant_check;
alter table public.programs add constraint programs_variant_check
  check (variant is null or variant in ('normal', 'short'));

-- Plans written before this migration kept the rhythm in raw_program.
update public.programs
set rhythm = raw_program->>'rhythm'
where rhythm is null and raw_program->>'rhythm' in ('Doux', 'Régulier', 'Soutenu');

alter table public.program_steps
  add column if not exists day_number smallint,
  add column if not exists available_on date,
  add column if not exists kind text not null default 'main';

alter table public.program_steps drop constraint if exists program_steps_kind_check;
alter table public.program_steps add constraint program_steps_kind_check
  check (kind in ('discovery', 'main', 'free'));
alter table public.program_steps drop constraint if exists program_steps_day_number_check;
alter table public.program_steps add constraint program_steps_day_number_check
  check (day_number is null or day_number between 1 and 60);

update public.program_steps set day_number = step_number where day_number is null;

create index if not exists programs_plan_id_idx on public.programs(plan_id) where plan_id is not null;

-- Retention by plan for the dashboard: started, finished and abandoned plans,
-- and how far people go. Read through the admin-only dashboard functions.
create or replace view private.plan_funnel as
select
  p.plan_id,
  p.status,
  count(*) as programs,
  avg(done.completed) filter (where done.completed is not null) as avg_completed_days,
  count(*) filter (where done.completed >= 7) as reached_week_2,
  count(*) filter (where done.completed >= 14) as reached_week_3
from public.programs p
left join lateral (
  select count(*) filter (where s.status = 'completed') as completed
  from public.program_steps s
  where s.program_id = p.id
) done on true
where p.plan_id is not null
group by p.plan_id, p.status;

revoke all on private.plan_funnel from public, anon, authenticated;
