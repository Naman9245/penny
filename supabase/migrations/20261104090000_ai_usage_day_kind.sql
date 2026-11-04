-- take_ai_call adds up one kind's calls across everyone for a day. The
-- (user_id, day, kind) key can't find those rows, so it read the whole
-- table while holding the day's lock; this index finds them directly.
create index ai_usage_day_kind on public.ai_usage (day, kind);
