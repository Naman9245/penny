-- How often each user asked Penny today. Nothing about anyone's money is
-- stored on the server: the analyze-month function reads the month from the
-- request, answers, and keeps only this count.
create table public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  calls integer not null default 0 check (calls >= 0),
  primary key (user_id, day)
);

comment on table public.ai_usage is
  'Calls to Penny''s AI per user per day (India time). Only the analyze-month function touches it.';

-- RLS with no policies: apps can neither read nor write this table. The
-- function uses the secret key, which bypasses RLS.
alter table public.ai_usage enable row level security;
revoke all on table public.ai_usage from anon, authenticated;

-- Counts one call for today. Returns the calls the user has left after this
-- one, -1 when the user is at their daily limit, or -2 when everyone together
-- is at the app's daily limit.
create function public.take_ai_call(
  p_user_id uuid,
  p_user_limit integer,
  p_total_limit integer
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  used integer;
begin
  -- One call at a time per day, so two at once can't both slip under a limit.
  perform pg_advisory_xact_lock(hashtext('penny.ai_usage:' || today::text));

  if (select coalesce(sum(calls), 0) from public.ai_usage where day = today)
      >= p_total_limit then
    return -2;
  end if;

  insert into public.ai_usage as usage (user_id, day, calls)
  values (p_user_id, today, 1)
  on conflict (user_id, day) do update
    set calls = usage.calls + 1
    where usage.calls < p_user_limit
  returning calls into used;

  if used is null then
    return -1;
  end if;
  return p_user_limit - used;
end;
$$;

-- Gives back a call that Gemini failed to answer.
create function public.refund_ai_call(p_user_id uuid)
returns void
language sql
set search_path = ''
as $$
  update public.ai_usage
  set calls = calls - 1
  where user_id = p_user_id
    and day = (now() at time zone 'Asia/Kolkata')::date
    and calls > 0;
$$;

revoke all on function public.take_ai_call(uuid, integer, integer)
  from public, anon, authenticated;
revoke all on function public.refund_ai_call(uuid)
  from public, anon, authenticated;
grant execute on function public.take_ai_call(uuid, integer, integer)
  to service_role;
grant execute on function public.refund_ai_call(uuid) to service_role;
