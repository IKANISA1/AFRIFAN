begin;

-- Allocation receipts stay immutable. A paid membership can advance from
-- allocated to fulfilled only after the matching activation and ledger write
-- have succeeded in the same transaction. Parser metadata is not authority.
create or replace function public.protect_committed_intent_reconciliation()
returns trigger language plpgsql security invoker set search_path='' as $$
declare
  v_fulfilled boolean;
  v_membership_id uuid;
begin
  if old.match_status='matched' and old.metadata->>'allocation_persisted'='true' then
    if new.match_status is distinct from old.match_status
      or new.match_type is distinct from old.match_type
      or new.user_id is distinct from old.user_id
      or new.club_id is distinct from old.club_id
      or new.country_code is distinct from old.country_code
      or new.parsed_sms_id is distinct from old.parsed_sms_id
      or new.target_table is distinct from old.target_table
      or new.target_record_id is distinct from old.target_record_id
      or new.reconciled_at is distinct from old.reconciled_at then
      raise exception 'INTENT_ALLOCATION_COMMITTED';
    end if;
    v_fulfilled:=coalesce(old.metadata->>'business_target_fulfilled'='true',false);
    if not v_fulfilled and old.target_table='membership_payment_orders' then
      select m.id into v_membership_id
      from public.membership_payment_orders o
      join public.payment_intents i on i.id=o.payment_intent_id
      join public.momo_ledger_entries l on l.parsed_sms_id=old.parsed_sms_id
      join public.fan_memberships m on m.user_id=o.user_id and m.club_id=o.club_id
      where o.id=old.target_record_id and o.activated_at is not null
        and o.user_id=old.user_id and o.club_id=old.club_id
        and i.id::text=old.metadata->>'intent_id' and i.status='fulfilled'
        and i.user_id=o.user_id and i.target_table=old.target_table
        and i.target_record_id=o.id and i.receiving_account_id=o.receiving_account_id
        and i.expected_amount=o.amount and i.currency=o.currency
        and l.ledger_status='posted' and l.entry_type='debit'
        and l.user_id=o.user_id and l.club_id=o.club_id
        and l.target_table=old.target_table and l.target_record_id=o.id
        and l.amount=o.amount and l.currency=o.currency
        and l.metadata->>'intent_id'=i.id::text
        and l.metadata->>'business_target_fulfilled'='true'
        and l.metadata->>'membership_id'=m.id::text;
      v_fulfilled:=v_membership_id is not null;
    end if;
    new.metadata:=(coalesce(new.metadata,'{}'::jsonb)-'membership_id')
      ||jsonb_build_object('allocation_persisted',true,
        'intent_id',old.metadata->'intent_id','business_target_fulfilled',v_fulfilled);
    if v_membership_id is not null then
      new.metadata:=new.metadata||jsonb_build_object('membership_id',v_membership_id);
    elsif v_fulfilled and old.metadata ? 'membership_id' then
      -- Once fulfilled, a response retry cannot erase or replace its receipt.
      new.metadata:=new.metadata||jsonb_build_object('membership_id',old.metadata->'membership_id');
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.protect_committed_intent_reconciliation()
  from public,anon,authenticated,service_role;

-- Repair historical membership receipts only where the guard can prove the
-- activated order, matching intent, membership and posted debit. No activation,
-- renewal, balance or financial amount is changed by this backfill.
update public.momo_reconciliations r
set metadata=r.metadata
where r.match_status='matched' and r.target_table='membership_payment_orders'
  and r.metadata->>'allocation_persisted'='true'
  and r.metadata->>'business_target_fulfilled' is distinct from 'true'
  and exists(select 1 from public.membership_payment_orders o
    where o.id=r.target_record_id and o.activated_at is not null);

commit;
