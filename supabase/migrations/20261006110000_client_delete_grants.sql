-- The ownership policies were added previously, but PostgreSQL also requires
-- the matching table privilege before an authenticated client can delete.
-- Subscription history and raw migration evidence remain server-only.

grant delete on public.louane_conversations, public.louane_messages,
  public.louane_memory, public.session_progress, public.user_preferences,
  public.programs to authenticated;
