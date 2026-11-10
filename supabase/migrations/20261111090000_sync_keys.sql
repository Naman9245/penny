-- A phone can sign in to a second account. Its rows keep their ids and go
-- up again under that account, so an id names a row only within one
-- account. Keyed by id alone, the second account's rows landed on the
-- first's and were refused, and it never synced. Each row is now keyed by
-- (user_id, id), like the note's (user_id, name).
--
-- The phone doesn't send user_id: it takes auth.uid() by default, which is
-- filled in before the upsert looks for a clash. The policies, the
-- sync_stamp() trigger and the (user_id, seq) indexes don't use the key, and
-- nothing else points at these ids.
do $$
declare
  t text;
begin
  foreach t in array array[
    'txns', 'budgets', 'goals', 'goal_deposits', 'tag_rules'
  ] loop
    execute format(
      'alter table public.%I drop constraint %I', t, t || '_pkey');
    execute format(
      'alter table public.%I add constraint %I primary key (user_id, id)',
      t, t || '_pkey');
  end loop;
end;
$$;
