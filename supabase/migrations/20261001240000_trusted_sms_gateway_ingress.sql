-- Receiver-settlement ingestion is a separately provisioned management capability.
-- No approved source/keys are seeded; SMS labels and HMAC alone do not prove settlement.
begin;
create table public.trusted_sms_ingress_config(id boolean primary key default true check(id),enabled boolean not null default false);
insert into public.trusted_sms_ingress_config values(true,false);
create table public.trusted_sms_gateways(
 id uuid primary key, receiver_account_id uuid not null references public.payment_receiver_accounts(id),
 club_id bigint not null references public.african_football_clubs(id), provider text not null check(provider ~ '^[a-z][a-z0-9_]{1,39}$'),
 country text not null check(country ~ '^[A-Z]{2}$'),currency text not null check(currency ~ '^[A-Z]{3}$'),
 protocol text not null default 'africlub.receiver-settlement.v1' check(protocol='africlub.receiver-settlement.v1'),
 source_review_reference text,provider_acceptance_reference text,enabled boolean not null default false,
 check(not enabled or coalesce(length(trim(source_review_reference)) between 12 and 200 and length(trim(provider_acceptance_reference)) between 12 and 200,false))
);
create table public.trusted_sms_gateway_keys(
 id uuid primary key,gateway_id uuid not null references public.trusted_sms_gateways(id),
 secret_env_name text not null unique check(secret_env_name ~ '^SMS_GATEWAY_KEY_[A-Z0-9_]{1,80}$'),
 enabled boolean not null default false,not_before timestamptz not null default now(),expires_at timestamptz not null,
 check(expires_at>not_before)
);
create table public.trusted_sms_gateway_events(
 id uuid primary key,gateway_id uuid not null references public.trusted_sms_gateways(id),
 key_id uuid not null references public.trusted_sms_gateway_keys(id),body_digest text not null,
 projection jsonb not null,provider text not null,provider_transaction_id text not null,
 receiver_account_id uuid not null references public.payment_receiver_accounts(id),club_id bigint not null,
 raw_sms_id uuid not null unique references public.momo_sms_raw(id) on delete restrict,
 target_kind text not null check(target_kind in ('membership','shop','ticket')),target_ids uuid[] not null,intent_id uuid references public.payment_intents(id),
 admitted_at timestamptz not null default clock_timestamp(),completed_at timestamptz,
 status text not null default 'pending' check(status in ('pending','confirmed','allocated','manual_review')),
 result jsonb,
 unique(provider,provider_transaction_id)
);
create table public.trusted_sms_gateway_nonces(
 key_id uuid not null references public.trusted_sms_gateway_keys(id),nonce uuid not null,
 event_id uuid not null references public.trusted_sms_gateway_events(id),body_digest text not null,expires_at timestamptz not null,
 primary key(key_id,nonce)
);
create index trusted_sms_gateway_nonce_expiry on public.trusted_sms_gateway_nonces(expires_at,key_id,nonce);
alter table public.trusted_sms_ingress_config enable row level security;
alter table public.trusted_sms_gateways enable row level security;
alter table public.trusted_sms_gateway_keys enable row level security;
alter table public.trusted_sms_gateway_events enable row level security;
alter table public.trusted_sms_gateway_nonces enable row level security;
revoke all on public.trusted_sms_ingress_config,public.trusted_sms_gateways,public.trusted_sms_gateway_keys,
 public.trusted_sms_gateway_events,public.trusted_sms_gateway_nonces from public,anon,authenticated,service_role;
-- Private management tables still deny stale human bearers at nested writes.
-- Service processing retains its separately authenticated gateway authority.
do $$ declare t text; begin
 foreach t in array array['trusted_sms_ingress_config','trusted_sms_gateways','trusted_sms_gateway_keys',
  'trusted_sms_gateway_events','trusted_sms_gateway_nonces'] loop
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
 end loop;
end $$;
-- Provisioning is an accountable database-owner change. Edge cannot self-enable a source.

create function public.get_trusted_sms_gateway_key(p_key_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k public.trusted_sms_gateway_keys;g public.trusted_sms_gateways;a public.payment_receiver_accounts;c public.african_football_clubs;
begin
 if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='GATEWAY_SERVICE_REQUIRED'; end if;
 select * into k from public.trusted_sms_gateway_keys where id=p_key_id;
 select * into g from public.trusted_sms_gateways where id=k.gateway_id;
 select * into a from public.payment_receiver_accounts where id=g.receiver_account_id;
 select * into c from public.african_football_clubs where id=g.club_id;
 if not coalesce((select enabled from public.trusted_sms_ingress_config where id),false)
  or not coalesce(k.enabled,false) or not coalesce(g.enabled,false)
  or not coalesce(length(trim(g.source_review_reference)) between 12 and 200 and length(trim(g.provider_acceptance_reference)) between 12 and 200,false) or not coalesce(a.is_active,false)
  or not coalesce(c.is_active,false) or k.not_before>clock_timestamp() or k.expires_at<=clock_timestamp()
  or c.country_iso_code is distinct from g.country or c.currency_code is distinct from g.currency
  or not exists(select 1 from public.partner_payment_routes r where r.club_id=g.club_id and r.partner_id=a.partner_id
    and r.status='active' and upper(r.country)=g.country and r.recipient_code=a.payee_number_or_code
    and (case lower(trim(r.provider)) when 'mtn' then 'mtn_rwanda' when 'mtn rwanda' then 'mtn_rwanda' else lower(trim(r.provider)) end)=g.provider)
 then return null; end if;
 return jsonb_build_object('gateway_id',g.id,'club_id',g.club_id,'secret_env_name',k.secret_env_name);
end $$;

create function public.admit_trusted_sms_gateway_evidence(p_key_id uuid,p_nonce uuid,p_created_at timestamptz,
 p_expires_at timestamptz,p_body_digest text,p_projection jsonb) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='8s' as $$
declare k public.trusted_sms_gateway_keys;g public.trusted_sms_gateways;a public.payment_receiver_accounts;
 e public.trusted_sms_gateway_events;n public.trusted_sms_gateway_nonces;
 i public.payment_intents;o public.membership_payment_orders;s public.shop_orders;t public.tickets;checkout public.pending_transactions;
 subject uuid;raw_id uuid;ids uuid[];kind text;intent uuid;amount integer;settled timestamptz;event uuid;checkout_ref text;
begin
 if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='GATEWAY_SERVICE_REQUIRED'; end if;
 if p_nonce is null or p_created_at is null or p_expires_at is null or p_body_digest !~ '^[A-Za-z0-9+/]{43}=$'
  or jsonb_typeof(p_projection) is distinct from 'object'
  or (select array_agg(key order by key) from jsonb_object_keys(p_projection) key) is distinct from
   array['amount','checkoutReference','country','currency','eventId','payerAccountDigest','protocol','provider','providerTransactionId','receiver','settledAt','settlementRecordDigest','settlementRecordId','settlementStatus']::text[]
  or p_projection->>'protocol' is distinct from 'africlub.receiver-settlement.v1' or p_projection->>'settlementStatus' is distinct from 'settled'
  or exists(select 1 from jsonb_each(p_projection) field where field.key<>'amount' and jsonb_typeof(field.value) is distinct from 'string')
  or p_projection->>'eventId' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or p_projection->>'checkoutReference' !~ '^[A-Za-z0-9_-]{1,128}$'
  or p_projection->>'providerTransactionId' !~ '^[A-Za-z0-9_-]{1,128}$'
  or p_projection->>'settlementRecordId' !~ '^[A-Za-z0-9_.:/-]{1,128}$'
  or p_projection->>'payerAccountDigest' !~ '^[0-9a-f]{64}$'
  or p_projection->>'settlementRecordDigest' !~ '^[0-9a-f]{64}$'
  or jsonb_typeof(p_projection->'amount') is distinct from 'number' or p_projection->>'amount' !~ '^[0-9]{1,10}$'
 then raise exception 'GATEWAY_INVALID_EVIDENCE'; end if;
 event:=(p_projection->>'eventId')::uuid;checkout_ref:=p_projection->>'checkoutReference';
 amount:=(p_projection->>'amount')::integer;settled:=(p_projection->>'settledAt')::timestamptz;
 if amount<=0 or p_created_at>clock_timestamp()+interval '30 seconds' or p_created_at<clock_timestamp()-interval '5 minutes'
  or p_expires_at<=clock_timestamp() or p_expires_at<p_created_at or p_expires_at-p_created_at>interval '5 minutes'
 then raise exception 'GATEWAY_EXPIRED_EVIDENCE'; end if;
 -- Expired freshness nonces can be reclaimed; immutable event/provider transaction
 -- identities remain durable anti-reuse evidence. Each admission removes at most 50.
 delete from public.trusted_sms_gateway_nonces where (key_id,nonce) in
  (select key_id,nonce from public.trusted_sms_gateway_nonces where expires_at<clock_timestamp()-interval '30 seconds'
   order by expires_at limit 50 for update skip locked);
 -- Serialize every event and nonce before any evidence insertion. Gateway/key
 -- revocation is checked again after these waits, against wall-clock time.
 perform pg_advisory_xact_lock(hashtextextended('gateway-event:'||event::text,0));
 perform pg_advisory_xact_lock(hashtextextended('gateway-nonce:'||p_key_id::text||':'||p_nonce::text,0));
 perform 1 from public.trusted_sms_ingress_config where id for share;
 select * into k from public.trusted_sms_gateway_keys where id=p_key_id for share;
 select * into g from public.trusted_sms_gateways where id=k.gateway_id for share;
 if public.get_trusted_sms_gateway_key(p_key_id) is null then raise exception using errcode='42501',message='GATEWAY_NOT_PROVISIONED'; end if;
 if p_created_at>clock_timestamp()+interval '30 seconds' or p_created_at<clock_timestamp()-interval '5 minutes'
  or p_expires_at<=clock_timestamp() or p_expires_at<p_created_at or p_expires_at-p_created_at>interval '5 minutes'
 then raise exception 'GATEWAY_EXPIRED_EVIDENCE'; end if;
 select * into a from public.payment_receiver_accounts where id=g.receiver_account_id;
 if p_projection->>'provider' is distinct from g.provider or p_projection->>'country' is distinct from g.country
  or p_projection->>'currency' is distinct from g.currency or p_projection->>'receiver' is distinct from a.payee_number_or_code
 then raise exception 'GATEWAY_RECEIVER_BINDING_MISMATCH'; end if;
 select * into n from public.trusted_sms_gateway_nonces where key_id=p_key_id and nonce=p_nonce;
 if n.key_id is not null and (n.event_id<>event or n.body_digest<>p_body_digest) then raise exception 'GATEWAY_NONCE_REUSED'; end if;
 select * into e from public.trusted_sms_gateway_events where id=event;
 if e.id is not null then
  if e.gateway_id<>g.id or e.body_digest<>p_body_digest or e.projection<>(p_projection-'payerAccountDigest') then raise exception 'GATEWAY_EVENT_CHANGED'; end if;
  insert into public.trusted_sms_gateway_nonces values(p_key_id,p_nonce,event,p_body_digest,p_expires_at) on conflict do nothing;
  return jsonb_build_object('event_id',e.id,'raw_sms_id',e.raw_sms_id,'replay',true,'status',e.status);
 end if;
 if settled>clock_timestamp()+interval '30 seconds' or settled<clock_timestamp()-interval '14 days' then raise exception 'GATEWAY_SETTLEMENT_TIME_INVALID'; end if;
 -- An exact server-created identity is mandatory. Equal amounts/payer names do
 -- not choose a user or business target. Only canonical active product targets.
 select * into i from public.payment_intents where id::text=checkout_ref and receiving_account_id=a.id;
 if i.id is not null then
  select * into o from public.membership_payment_orders where id=i.target_record_id and payment_intent_id=i.id;
  if i.target_table<>'membership_payment_orders' or o.id is null or o.club_id<>g.club_id or o.user_id<>i.user_id
   or o.partner_id is distinct from a.partner_id or o.receiving_account_id<>a.id
   or o.payment_provider is distinct from g.provider or o.payment_country is distinct from g.country
   or o.payment_recipient is distinct from a.payee_number_or_code or o.currency<>g.currency or o.amount<>amount
   or i.expected_amount<>amount or i.currency<>g.currency or i.status<>'pending' or i.expires_at<=clock_timestamp()
   or settled<i.created_at-interval '30 seconds' then raise exception 'GATEWAY_CHECKOUT_BINDING_MISMATCH'; end if;
  subject:=i.user_id;ids:=array[o.id];intent:=i.id;kind:='membership';
 else
  select * into s from public.shop_orders where momo_reference=checkout_ref and club_id=g.club_id;
  if s.id is not null then
   if s.partner_id is distinct from a.partner_id or s.payment_receipt is null
    or s.payment_receipt->>'receiver_id'<>a.id::text or s.payment_receipt->>'provider'<>g.provider
    or s.payment_receipt->>'currency'<>g.currency or s.payment_receipt->>'country'<>g.country
    or s.total<>amount or s.status<>'pending' or s.reservation_expires_at<=clock_timestamp()
    or (select count(*) from public.shop_orders where momo_reference=checkout_ref)<>1
    or settled<s.created_at-interval '30 seconds' then raise exception 'GATEWAY_CHECKOUT_BINDING_MISMATCH'; end if;
   subject:=s.user_id;ids:=array[s.id];kind:='shop';
  else
   select * into t from public.tickets where momo_reference=checkout_ref and club_id=g.club_id order by id limit 1;
   if t.id is null or exists(select 1 from public.tickets other where other.momo_reference=checkout_ref
      and (other.user_id<>t.user_id or other.club_id<>g.club_id or other.status<>'pending'))
    or exists(select 1 from public.tickets ticket join public.matches m on m.id=ticket.match_id
      where ticket.momo_reference=checkout_ref and (m.club_id<>g.club_id or m.partner_id is distinct from a.partner_id))
    or (select sum(amount_paid) from public.tickets where momo_reference=checkout_ref)<>amount
    or settled<t.created_at-interval '30 seconds' then raise exception 'GATEWAY_CHECKOUT_NOT_FOUND'; end if;
   subject:=t.user_id;select array_agg(id order by id) into ids from public.tickets where momo_reference=checkout_ref;kind:='ticket';
  end if;
  select * into checkout from public.pending_transactions where reference=checkout_ref and user_id=subject;
  if checkout.id is null or checkout.reference is distinct from checkout_ref or checkout.status<>'pending'
   or checkout.amount<>amount or checkout.recipient_momo<>a.payee_number_or_code
   or (case lower(trim(checkout.provider)) when 'mtn' then 'mtn_rwanda' when 'mtn rwanda' then 'mtn_rwanda' else lower(trim(checkout.provider)) end)<>g.provider
  then raise exception 'GATEWAY_CHECKOUT_BINDING_MISMATCH'; end if;
 end if;
 if subject is null then raise exception 'GATEWAY_PAYER_REQUIRED'; end if;
 perform pg_advisory_xact_lock(hashtextextended(subject::text,21000));
 -- Closure and other subject-bound mutations may hold this final admission
 -- lock. Revalidate the signed window after that wait before storing evidence.
 if p_created_at>clock_timestamp()+interval '30 seconds' or p_created_at<clock_timestamp()-interval '5 minutes'
  or p_expires_at<=clock_timestamp() or p_expires_at<p_created_at or p_expires_at-p_created_at>interval '5 minutes'
 then raise exception 'GATEWAY_EXPIRED_EVIDENCE'; end if;
 if exists(select 1 from public.account_erasure_jobs where user_id=subject) then raise exception 'GATEWAY_SUBJECT_CLOSED'; end if;
 if not exists(select 1 from auth.users u where u.id=subject and u.phone_confirmed_at is not null
  and regexp_replace(u.phone,'\D','','g') ~ '^[0-9]{8,15}$'
  and encode(extensions.digest(convert_to('africlub-payer-v1:'||g.provider||':'||g.country||':'||regexp_replace(u.phone,'\D','','g'),'UTF8'),'sha256'),'hex')=p_projection->>'payerAccountDigest')
 then raise exception 'GATEWAY_PAYER_BINDING_MISMATCH'; end if;

 raw_id:=gen_random_uuid();
 insert into public.momo_sms_raw(id,user_id,device_message_key,sender,sms_body,provider,country_code,sms_received_at,ingestion_source,club_id)
 values(raw_id,subject,'gateway:'||event::text,g.provider,'[VERIFIED RECEIVER SETTLEMENT PROJECTION]',g.provider,g.country,settled,'management_gateway',g.club_id);
 insert into public.trusted_sms_gateway_events(id,gateway_id,key_id,body_digest,projection,provider,provider_transaction_id,receiver_account_id,club_id,raw_sms_id,target_kind,target_ids,intent_id)
 values(event,g.id,k.id,p_body_digest,p_projection-'payerAccountDigest',g.provider,p_projection->>'providerTransactionId',a.id,g.club_id,raw_id,kind,ids,intent);
 insert into public.trusted_sms_gateway_nonces values(p_key_id,p_nonce,event,p_body_digest,p_expires_at);
 return jsonb_build_object('event_id',event,'raw_sms_id',raw_id,'replay',false,'status','pending');
end $$;

create function public.get_trusted_sms_gateway_event(p_event_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='GATEWAY_SERVICE_REQUIRED'; end if;
 return(select jsonb_build_object('gateway_id',gateway_id,'club_id',club_id) from public.trusted_sms_gateway_events where id=p_event_id);
end $$;

create function public.process_trusted_sms_gateway_evidence(p_event_id uuid) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='8s' as $$
declare e public.trusted_sms_gateway_events;g public.trusted_sms_gateways;a public.payment_receiver_accounts;r public.momo_sms_raw;
 claim jsonb;interpretation jsonb;receipt jsonb;parsed uuid;attempt uuid;token uuid;settled timestamptz;v_status text;
begin
 if auth.role() is distinct from 'service_role' then raise exception using errcode='42501',message='GATEWAY_SERVICE_REQUIRED'; end if;
 select * into e from public.trusted_sms_gateway_events where id=p_event_id;
 if e.id is null then raise exception 'GATEWAY_EVIDENCE_REQUIRED'; end if;
 -- The evidence advisory lock precedes every legacy row lock, preserving the
 -- canonical allocation/parse lock order. No competing money writer is added.
 perform pg_advisory_xact_lock(hashtextextended('momo-evidence:'||e.raw_sms_id::text,0));
 select * into e from public.trusted_sms_gateway_events where id=p_event_id for update;
 if e.completed_at is not null then return e.result||jsonb_build_object('replay',true); end if;
 perform 1 from public.trusted_sms_ingress_config where id for share;
 perform 1 from public.trusted_sms_gateway_keys where id=e.key_id for share;
 select * into g from public.trusted_sms_gateways where id=e.gateway_id for share;
 if public.get_trusted_sms_gateway_key(e.key_id) is null then raise exception using errcode='42501',message='GATEWAY_NOT_PROVISIONED'; end if;
 select * into r from public.momo_sms_raw where id=e.raw_sms_id;
 if e.target_kind='membership' then
  perform 1 from public.payment_intents where id=e.intent_id for update;
 else
  perform 1 from public.pending_transactions where reference=e.projection->>'checkoutReference' and user_id=r.user_id for update;
 end if;
 select * into a from public.payment_receiver_accounts where id=e.receiver_account_id for share;
 perform 1 from public.partner_payment_routes route where route.club_id=g.club_id and route.partner_id=a.partner_id
  and route.status='active' and route.recipient_code=a.payee_number_or_code and upper(route.country)=g.country
  and (case lower(trim(route.provider)) when 'mtn' then 'mtn_rwanda' when 'mtn rwanda' then 'mtn_rwanda' else lower(trim(route.provider)) end)=g.provider for share;
 -- Re-evaluate after target/receiver/route waits, with authority rows held through commit.
 if public.get_trusted_sms_gateway_key(e.key_id) is null then raise exception using errcode='42501',message='GATEWAY_NOT_PROVISIONED'; end if;
 select * into r from public.momo_sms_raw where id=e.raw_sms_id;
 if e.receiver_account_id is distinct from g.receiver_account_id or e.club_id is distinct from g.club_id
  or e.provider is distinct from g.provider
  or not exists(select 1 from public.trusted_sms_gateway_keys key where key.id=e.key_id and key.gateway_id=e.gateway_id)
  or r.id is null or r.sms_body_redacted_at is not null or r.sms_body<>'[VERIFIED RECEIVER SETTLEMENT PROJECTION]'
  or r.provider is distinct from e.provider or r.club_id is distinct from e.club_id or r.country_code is distinct from g.country
  or e.projection->>'receiver' is distinct from a.payee_number_or_code or e.projection->>'currency' is distinct from g.currency
  or e.projection->>'provider' is distinct from e.provider or e.projection->>'country' is distinct from g.country
 then raise exception 'GATEWAY_EVIDENCE_CHANGED'; end if;
 claim:=public.claim_momo_sms_parse(r.id,r.user_id,r.updated_at,false);
 if claim->>'status'<>'claimed' then raise exception 'GATEWAY_PARSE_CLAIM_REQUIRED'; end if;
 token:=(claim->>'token')::uuid;settled:=(e.projection->>'settledAt')::timestamptz;
 insert into public.momo_parse_attempts(raw_sms_id,user_id,provider,model,attempt_number,status,prompt_version)
 values(r.id,r.user_id,'management_gateway','receiver-settlement-v1',1,'pending','deterministic-v1') returning id into attempt;
 interpretation:=public.persist_momo_sms_parse(r.id,r.user_id,token,jsonb_build_object(
  'parser_provider','management_gateway','parser_model','receiver-settlement-v1','parse_status','parsed','confidence',1,
  'tx_direction','debit','tx_type','payment','tx_category','payment','cashflow_bucket','expense',
  'momo_tx_id',e.provider_transaction_id,'amount',(e.projection->>'amount')::integer,'currency',g.currency,
  'tx_datetime',settled,'payee_number_or_code',a.payee_number_or_code,
  'structured_data',jsonb_build_object('gateway_event_id',e.id,'settlement_record_digest',e.projection->>'settlementRecordDigest')));
 parsed:=(interpretation->>'id')::uuid;
 if e.target_kind='membership' then
  receipt:=public.allocate_momo_payment_intent(parsed,e.intent_id);
 else
  receipt:=public.confirm_club_commerce_payment(e.target_kind,e.target_ids,r.user_id,e.projection->>'checkoutReference',
   (e.projection->>'amount')::integer,e.club_id,a.partner_id,e.provider,a.payee_number_or_code,g.currency,g.country,parsed);
 end if;
 v_status:=receipt->>'status';
 if v_status not in ('allocated','confirmed','manual_review') or v_status is null then raise exception 'GATEWAY_CONFIRMATION_REQUIRED'; end if;
 if not public.finish_momo_sms_parse(r.id,r.user_id,token,true,attempt,'{}','{}',null) then raise exception 'GATEWAY_PARSE_COMPLETION_REQUIRED'; end if;
 receipt:=jsonb_build_object('event_id',e.id,'status',v_status,'replay',false);
 update public.trusted_sms_gateway_events set status=v_status,completed_at=clock_timestamp(),result=receipt where id=e.id;
 return receipt;
end $$;

create function public.guard_trusted_sms_gateway_key() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.id is distinct from old.id or new.gateway_id is distinct from old.gateway_id or new.secret_env_name is distinct from old.secret_env_name
 then raise exception 'GATEWAY_KEY_IDENTITY_IMMUTABLE'; end if;
 return new;
end $$;
create trigger trusted_sms_gateway_key_immutable before update on public.trusted_sms_gateway_keys
 for each row execute function public.guard_trusted_sms_gateway_key();
create function public.guard_trusted_sms_gateway_event() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' or (to_jsonb(new)-array['status','result','completed_at']) is distinct from (to_jsonb(old)-array['status','result','completed_at'])
  or old.completed_at is not null then raise exception 'GATEWAY_EVIDENCE_IMMUTABLE'; end if;
 return new;
end $$;
create trigger trusted_sms_gateway_event_immutable before update or delete on public.trusted_sms_gateway_events
 for each row execute function public.guard_trusted_sms_gateway_event();
revoke insert,update,delete on public.momo_sms_raw from authenticated,anon;
do $$declare p record;begin
 for p in select policyname from pg_policies where schemaname='public' and tablename='momo_sms_raw' and permissive='PERMISSIVE' and cmd in ('INSERT','UPDATE','DELETE','ALL') loop
  execute format('drop policy %I on public.momo_sms_raw',p.policyname);
 end loop;
end $$;
revoke all on function public.get_trusted_sms_gateway_key(uuid),
 public.admit_trusted_sms_gateway_evidence(uuid,uuid,timestamptz,timestamptz,text,jsonb),
 public.get_trusted_sms_gateway_event(uuid),public.process_trusted_sms_gateway_evidence(uuid),
 public.guard_trusted_sms_gateway_event(),public.guard_trusted_sms_gateway_key() from public,anon,authenticated,service_role;
grant execute on function public.get_trusted_sms_gateway_key(uuid),
 public.admit_trusted_sms_gateway_evidence(uuid,uuid,timestamptz,timestamptz,text,jsonb),
 public.get_trusted_sms_gateway_event(uuid),public.process_trusted_sms_gateway_evidence(uuid) to service_role;
notify pgrst,'reload schema';
commit;
