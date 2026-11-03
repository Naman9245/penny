-- Backup and sync for signed-in users: the phone's entries, budgets, goals
-- and the money put toward them, My needs rules and the note to Penny, one
-- table each, every row under its account. Only that account can read or
-- write its rows, and anonymous sign-ins (the AI's, before anyone signs in)
-- can't sync at all. SMS text, SMS fingerprints, the chat and Penny's
-- reports and plans never leave the phone, so nothing here holds them.
--
-- sync_stamp() keeps the rules:
-- * Every change takes the next number from sync_seq, so a phone asks for
--   "everything after N".
-- * One account's changes are written one transaction at a time, so its
--   numbers commit in order and a phone never skips one.
-- * The newer edit wins: an update whose updated_at isn't later than the
--   row's is dropped.
-- * Rows never move between accounts, and deletes stay soft (deleted_at),
--   so they reach every phone.

create sequence public.sync_seq;
revoke all on sequence public.sync_seq from public, anon, authenticated;
grant usage on sequence public.sync_seq to authenticated;

create function public.sync_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at <= old.updated_at then
      return null;
    end if;
    new.user_id := old.user_id;
  end if;
  perform pg_advisory_xact_lock(hashtext('penny.sync:' || new.user_id::text));
  new.seq := nextval('public.sync_seq');
  return new;
end;
$$;

-- It runs as a trigger only; nobody calls it.
revoke all on function public.sync_stamp() from public, anon, authenticated;

create table public.txns (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  amount_paise bigint not null check (amount_paise > 0),
  type text not null check (type in ('debit', 'credit')),
  category_id text not null check (char_length(category_id) <= 40),
  merchant text check (char_length(merchant) <= 500),
  occurred_at timestamptz not null,
  source text not null check (char_length(source) <= 20),
  tag text check (char_length(tag) <= 20),
  payee_is_person boolean,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq bigint not null
);
comment on table public.txns is
  'A signed-in user''s entries, synced from their phones. The SMS fingerprint stays on the phone.';

create table public.budgets (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  budget_key text not null check (char_length(budget_key) <= 40),
  amount_paise bigint not null check (amount_paise > 0),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq bigint not null
);
comment on table public.budgets is
  'A signed-in user''s monthly amount per category, synced from their phones.';

create table public.goals (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null check (char_length(title) <= 200),
  target_paise bigint not null check (target_paise > 0),
  deadline timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq bigint not null
);
comment on table public.goals is
  'What a signed-in user is saving for, synced from their phones.';

create table public.goal_deposits (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  goal_id uuid not null,
  amount_paise bigint not null check (amount_paise <> 0),
  occurred_at timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq bigint not null
);
comment on table public.goal_deposits is
  'Money put toward a goal, or taken out as a negative amount, synced from a signed-in user''s phones.';

create table public.tag_rules (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  kind text not null check (char_length(kind) <= 20),
  rule_key text not null check (char_length(rule_key) <= 200),
  tag text not null check (char_length(tag) <= 20),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq bigint not null
);
comment on table public.tag_rules is
  'A signed-in user''s My needs rules, synced from their phones.';

-- Only the note to Penny; the phone's other settings stay on the phone.
create table public.prefs (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (name in ('note')),
  value text not null check (char_length(value) <= 1000),
  updated_at timestamptz not null,
  seq bigint not null,
  primary key (user_id, name)
);
comment on table public.prefs is
  'A signed-in user''s note to Penny, synced from their phones.';

-- The same rules, trigger and index for every synced table.
do $$
declare
  t text;
  own constant text :=
    'user_id = (select auth.uid()) '
    'and (select (auth.jwt() ->> ''is_anonymous'')::boolean) is not true';
begin
  foreach t in array array[
    'txns', 'budgets', 'goals', 'goal_deposits', 'tag_rules', 'prefs'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon', t);
    -- Deletes are soft; only deleting the account removes rows, by cascade.
    execute format(
      'revoke delete, truncate, references, trigger on table public.%I '
      'from authenticated', t);
    execute format(
      'create policy "Own rows, signed in" on public.%I '
      'for select to authenticated using (%s)', t, own);
    execute format(
      'create policy "Add own rows, signed in" on public.%I '
      'for insert to authenticated with check (%s)', t, own);
    execute format(
      'create policy "Change own rows, signed in" on public.%I '
      'for update to authenticated using (%s) with check (%s)', t, own, own);
    execute format(
      'create trigger %I before insert or update on public.%I '
      'for each row execute function public.sync_stamp()',
      t || '_sync_stamp', t);
    execute format(
      'create index %I on public.%I (user_id, seq)', t || '_user_seq', t);
  end loop;
end;
$$;
