-- Autopays: payments that go out by themselves (a UPI autopay, a mandate, a
-- SIP, an EMI), found from messages or added by hand, so Penny can remind
-- before each one. Synced like the other tables: only the signed-in
-- account's own rows, soft deletes, and the next number from sync_seq.
create table public.autopays (
  id uuid not null,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (char_length(name) <= 100),
  amount_paise bigint not null check (amount_paise > 0),
  category_id text check (char_length(category_id) <= 40),
  every text not null
    check (every in ('weekly', 'monthly', 'quarterly', 'yearly')),
  next_on timestamptz,
  last_paid_on timestamptz,
  paused boolean not null default false,
  ended_at timestamptz,
  from_message boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  seq bigint not null,
  primary key (user_id, id)
);
comment on table public.autopays is
  'A signed-in user''s autopays, synced from their phones.';

alter table public.autopays enable row level security;
revoke all on table public.autopays from anon;
-- Deletes are soft; only deleting the account removes rows, by cascade.
revoke delete, truncate, references, trigger on table public.autopays
  from authenticated;
create policy "Own rows, signed in" on public.autopays
  for select to authenticated
  using (user_id = (select auth.uid())
    and (select (auth.jwt() ->> 'is_anonymous')::boolean) is not true);
create policy "Add own rows, signed in" on public.autopays
  for insert to authenticated
  with check (user_id = (select auth.uid())
    and (select (auth.jwt() ->> 'is_anonymous')::boolean) is not true);
create policy "Change own rows, signed in" on public.autopays
  for update to authenticated
  using (user_id = (select auth.uid())
    and (select (auth.jwt() ->> 'is_anonymous')::boolean) is not true)
  with check (user_id = (select auth.uid())
    and (select (auth.jwt() ->> 'is_anonymous')::boolean) is not true);
create trigger autopays_sync_stamp before insert or update on public.autopays
  for each row execute function public.sync_stamp();
create index autopays_user_seq on public.autopays (user_id, seq);
