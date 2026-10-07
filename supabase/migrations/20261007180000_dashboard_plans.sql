-- Retention by goal plan for the dashboard (dashboard/, « Rétention » tab).
-- Reads private.plan_funnel (20261007120000_goal_plans.sql): one row per plan
-- and status. Admin-only, like the other dashboard_* functions.

create or replace function public.dashboard_plans()
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

  select coalesce(jsonb_agg(jsonb_build_object(
    'plan_id', f.plan_id,
    'status', f.status,
    'programs', f.programs,
    'avg_completed_days', round(f.avg_completed_days, 1),
    'reached_week_2', f.reached_week_2,
    'reached_week_3', f.reached_week_3
  ) order by f.plan_id, f.status), '[]'::jsonb)
  into result
  from private.plan_funnel f;

  return result;
end;
$$;

revoke all on function public.dashboard_plans() from public, anon;
grant execute on function public.dashboard_plans() to authenticated;
