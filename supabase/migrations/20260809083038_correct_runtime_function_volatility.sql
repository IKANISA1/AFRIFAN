begin;

-- These routines were declared STABLE even though their execution paths call
-- helpers PostgreSQL correctly classifies as VOLATILE. In particular,
-- fet_get_wallet can create a missing membership. Marking callers VOLATILE is
-- the conservative contract: it prevents optimizer reuse without broadening
-- any EXECUTE grant or changing the existing SECURITY DEFINER boundary.
alter function public.get_club_member_registry(
  bigint,
  text,
  text,
  text,
  integer,
  integer
) volatile;

alter function public.fet_get_wallet(bigint) volatile;

alter function public.fet_admin_get_wallet_overview(
  bigint,
  text,
  integer,
  integer
) volatile;

alter function public.fet_admin_get_wallet_ledger(
  bigint,
  text,
  uuid,
  integer,
  integer
) volatile;

alter function public.prediction_challenge_summary_json(uuid, uuid) volatile;

commit;
