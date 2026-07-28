-- The registry seeds use dotted hierarchical keys. Re-assert the corrected
-- constraint for already-migrated environments as well as fresh resets.
alter table if exists public.runtime_copy
  drop constraint if exists runtime_copy_key_check;

alter table if exists public.runtime_copy
  add constraint runtime_copy_key_check
  check (copy_key ~ '^[a-z0-9][a-z0-9_.:-]*$');
