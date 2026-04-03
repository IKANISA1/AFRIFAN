-- ==========================================================================
-- Link MoMo SMS pipeline tables to the countries table
-- ==========================================================================
-- The `momo_sms_raw` table had `country text` as a plain text column.
-- This migration renames it to `country_code`, adds an FK to `countries(id)`,
-- and propagates it down through the parsed → ledger chain so every
-- transaction is traceable to a specific country entry.

-- ── 1. momo_sms_raw: rename country → country_code + FK ──────────────────
alter table public.momo_sms_raw
  rename column country to country_code;

alter table public.momo_sms_raw
  add constraint fk_momo_sms_raw_country
    foreign key (country_code)
    references public.countries(id)
    on delete set null;

create index if not exists idx_momo_sms_raw_country_code
  on public.momo_sms_raw (country_code);

-- ── 2. momo_sms_parsed: add country_code column + FK ─────────────────────
alter table public.momo_sms_parsed
  add column if not exists country_code text
    references public.countries(id)
    on delete set null;

create index if not exists idx_momo_sms_parsed_country_code
  on public.momo_sms_parsed (country_code);

-- ── 3. momo_ledger_entries: add country_code column + FK ─────────────────
alter table public.momo_ledger_entries
  add column if not exists country_code text
    references public.countries(id)
    on delete set null;

create index if not exists idx_momo_ledger_entries_country_code
  on public.momo_ledger_entries (country_code);

-- ── 4. momo_reconciliations: add country_code column + FK ────────────────
alter table public.momo_reconciliations
  add column if not exists country_code text
    references public.countries(id)
    on delete set null;

-- ── 5. Backfill: propagate country_code from raw → parsed → ledger ───────
-- If momo_sms_raw already has country_code values, cascade them down.

update public.momo_sms_parsed p
  set country_code = r.country_code
  from public.momo_sms_raw r
  where p.raw_sms_id = r.id
    and p.country_code is null
    and r.country_code is not null;

update public.momo_ledger_entries le
  set country_code = p.country_code
  from public.momo_sms_parsed p
  where le.parsed_sms_id = p.id
    and le.country_code is null
    and p.country_code is not null;

update public.momo_reconciliations rc
  set country_code = p.country_code
  from public.momo_sms_parsed p
  where rc.parsed_sms_id = p.id
    and rc.country_code is null
    and p.country_code is not null;
