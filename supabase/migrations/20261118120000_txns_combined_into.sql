-- What a combined entry was made of: each original, deleted the usual way,
-- keeps the id of the entry it was combined into, so the combined one can
-- show its parts and be split apart again on any phone.
alter table public.txns
  add column if not exists combined_into uuid;

comment on column public.txns.combined_into is
  'For an entry combined into another: that entry''s id.';
