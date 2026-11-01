-- Report looks and chat messages count against separate daily limits.
alter table public.ai_usage
  add column kind text not null default 'report'
    check (kind in ('report', 'chat'));
alter table public.ai_usage drop constraint ai_usage_pkey;
alter table public.ai_usage add primary key (user_id, day, kind);

-- Counts one call of [p_kind] for today. Returns the calls of that kind the
-- user has left after this one, -1 when the user is at their daily limit,
-- or -2 when everyone together is at the app's daily limit.
create function public.take_ai_call(
  p_user_id uuid,
  p_kind text,
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
  -- One call of a kind at a time per day, so two at once can't both slip
  -- under a limit.
  perform pg_advisory_xact_lock(
    hashtext('penny.ai_usage:' || p_kind || ':' || today::text)
  );

  if (
    select coalesce(sum(calls), 0)
    from public.ai_usage
    where day = today and kind = p_kind
  ) >= p_total_limit then
    return -2;
  end if;

  insert into public.ai_usage as usage (user_id, day, kind, calls)
  values (p_user_id, today, p_kind, 1)
  on conflict (user_id, day, kind) do update
    set calls = usage.calls + 1
    where usage.calls < p_user_limit
  returning calls into used;

  if used is null then
    return -1;
  end if;
  return p_user_limit - used;
end;
$$;

-- Gives back a call of [p_kind] that Gemini failed to answer.
create function public.refund_ai_call(p_user_id uuid, p_kind text)
returns void
language sql
set search_path = ''
as $$
  update public.ai_usage
  set calls = calls - 1
  where user_id = p_user_id
    and day = (now() at time zone 'Asia/Kolkata')::date
    and kind = p_kind
    and calls > 0;
$$;

-- The deployed analyze-month still calls the old signatures until it is
-- redeployed; keep them working on top of the new ones until then.
create or replace function public.take_ai_call(
  p_user_id uuid,
  p_user_limit integer,
  p_total_limit integer
)
returns integer
language sql
set search_path = ''
as $$
  select public.take_ai_call(p_user_id, 'report', p_user_limit, p_total_limit);
$$;

create or replace function public.refund_ai_call(p_user_id uuid)
returns void
language sql
set search_path = ''
as $$
  select public.refund_ai_call(p_user_id, 'report');
$$;

revoke all on function public.take_ai_call(uuid, text, integer, integer)
  from public, anon, authenticated;
revoke all on function public.refund_ai_call(uuid, text)
  from public, anon, authenticated;
grant execute on function public.take_ai_call(uuid, text, integer, integer)
  to service_role;
grant execute on function public.refund_ai_call(uuid, text) to service_role;
