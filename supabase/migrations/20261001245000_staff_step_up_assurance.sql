-- Human staff assurance is separate from tenant/role authority and service jobs.
-- Gateway-verified JWT claims are the only input; client/user metadata is ignored.
create function public.staff_step_up_allowed() returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare v_claims jsonb:=auth.jwt(); v_now numeric:=extract(epoch from clock_timestamp()); v_amr jsonb; v_time numeric;
begin
  if auth.role() is distinct from 'authenticated' or v_claims->>'role' is distinct from 'authenticated'
    or auth.uid() is null or v_claims->>'sub' is distinct from auth.uid()::text
    or v_claims->>'aal' is distinct from 'aal2' or v_claims->'is_anonymous' is distinct from 'false'::jsonb
    or not public.account_access_allowed() or jsonb_typeof(v_claims->'amr') is distinct from 'array' then return false; end if;
  if jsonb_array_length(v_claims->'amr') not between 1 and 16 then return false; end if;
  if jsonb_typeof(v_claims->'exp') is distinct from 'number' then return false; end if;
  v_time:=(v_claims->>'exp')::numeric;
  if v_time<=v_now or v_time>9007199254740991 or mod(v_time,1)<>0 then return false; end if;
  for v_amr in select value from jsonb_array_elements(v_claims->'amr') loop
    if v_amr->>'method' in ('totp','mfa/totp') and jsonb_typeof(v_amr->'timestamp')='number' then
      v_time:=(v_amr->>'timestamp')::numeric;
      if v_time>=v_now-300 and v_time<=v_now+30 and abs(v_time)<=9007199254740991 and mod(v_time,1)=0 then return true; end if;
    end if;
  end loop;
  return false;
exception when others then return false;
end; $$;
create function public.assert_staff_step_up() returns void
language plpgsql volatile security definer set search_path='' as $$
begin
  if not public.staff_step_up_allowed() then raise exception 'STAFF_STEP_UP_REQUIRED' using errcode='42501'; end if;
end; $$;
revoke all on function public.staff_step_up_allowed(), public.assert_staff_step_up() from public,anon,authenticated,service_role;
grant execute on function public.staff_step_up_allowed(), public.assert_staff_step_up() to authenticated;

-- Current assignments remain authority even when an RPC bypasses table RLS.
-- Statement checks do not lock grants before a possible target-row wait; row
-- checks lock the current qualifying assignment after that wait.
create function public.assert_staff_configuration_role(p_row jsonb,p_lock boolean default false) returns void
language plpgsql volatile security definer set search_path='' as $$
declare v_club bigint; v_assignment uuid;
begin
  if p_row ? 'club_id' then v_club:=nullif(p_row->>'club_id','')::bigint;
  elsif p_row ? 'feature_id' then
    select club_id into v_club from public.platform_features where id=(p_row->>'feature_id')::uuid;
  end if;
  if p_lock then
    select a.id into v_assignment from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null
      and (a.role in ('admin','super_admin') or ((p_row is null or (v_club is not null and a.club_id=v_club)) and a.role in ('club_admin','club_moderator','partner','rayon_sport','bank')))
      order by a.id limit 1 for share;
  else
    select a.id into v_assignment from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null
      and (a.role in ('admin','super_admin') or ((p_row is null or (v_club is not null and a.club_id=v_club)) and a.role in ('club_admin','club_moderator','partner','rayon_sport','bank')))
      order by a.id limit 1;
  end if;
  if v_assignment is null then raise exception 'STAFF_ADMIN_REQUIRED' using errcode='42501'; end if;
  perform public.assert_account_active(); perform public.assert_staff_step_up();
end; $$;
revoke all on function public.assert_staff_configuration_role(jsonb,boolean) from public,anon,authenticated,service_role;

-- Commercial pricing/configuration retains a stricter role boundary than CMS.
create function public.assert_staff_commercial_role(p_row jsonb,p_lock boolean) returns void
language plpgsql volatile security definer set search_path='' as $$
declare v_assignment uuid;
begin
 if p_lock then
  select a.id into v_assignment from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null
   and (a.role in ('admin','super_admin') or (a.role='club_admin' and (p_row is null or (a.club_id is not null and a.club_id=nullif(p_row->>'club_id','')::bigint))))
   order by a.id limit 1 for share;
 else
  select a.id into v_assignment from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null
   and (a.role in ('admin','super_admin') or (a.role='club_admin' and (p_row is null or (a.club_id is not null and a.club_id=nullif(p_row->>'club_id','')::bigint))))
   order by a.id limit 1;
 end if;
 perform public.assert_account_active(); perform public.assert_staff_step_up();
 if v_assignment is null then raise exception 'STAFF_COMMERCIAL_ADMIN_REQUIRED' using errcode='42501'; end if;
end; $$;
revoke all on function public.assert_staff_commercial_role(jsonb,boolean) from public,anon,authenticated,service_role;

-- Association edits must use a partner already mapped to the selected club by
-- the canonical stored sources. The BEFORE-row guard cannot make its own NEW
-- partner association qualify. Lock one actual source and recheck after waits.
create function public.assert_staff_commercial_partner(p_row jsonb) returns void
language plpgsql volatile security definer set search_path='' as $$
declare v_club bigint:=nullif(p_row->>'club_id','')::bigint;
 v_partner uuid:=nullif(p_row->>'partner_id','')::uuid; v_source text; v_binding uuid;
begin
 if v_club is null or v_partner is null then return; end if;
 perform 1 from public.partners where id=v_partner for share;
 if not found then raise exception 'STAFF_COMMERCIAL_PARTNER_REQUIRED' using errcode='42501'; end if;
 foreach v_source in array array['public.partner_payment_routes','public.initiatives','public.matches','public.membership_packages','public.shop_products','public.shop_orders'] loop
  execute format('select id from %s where club_id=$1 and partner_id=$2 order by id limit 1 for share',v_source) into v_binding using v_club,v_partner;
  exit when v_binding is not null;
 end loop;
 perform public.assert_account_active(); perform public.assert_staff_step_up();
 perform public.assert_staff_commercial_role(p_row,true);
 if v_binding is null or not coalesce(v_partner=any(public.resolve_partner_ids_for_club(v_club)),false) then
  raise exception 'STAFF_COMMERCIAL_PARTNER_REQUIRED' using errcode='42501';
 end if;
end; $$;
revoke all on function public.assert_staff_commercial_partner(jsonb) from public,anon,authenticated,service_role;

-- Only the existing order triggers can create this transaction-local receipt.
-- Stored order items and lifecycle, rather than fake trigger fields, bind it.
create table public.staff_shop_counter_context (
  transaction_id bigint not null, order_id uuid not null, product_id uuid not null,
  delta integer not null check(delta<>0), primary key(transaction_id,order_id,product_id)
);
alter table public.staff_shop_counter_context enable row level security;
revoke all on public.staff_shop_counter_context from public,anon,authenticated,service_role;
create policy account_lifecycle_access on public.staff_shop_counter_context as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed());
create trigger account_lifecycle_statement_guard before insert or update or delete on public.staff_shop_counter_context for each statement execute function public.guard_account_lifecycle_mutation();
create trigger account_lifecycle_mutation_guard before insert or update or delete on public.staff_shop_counter_context for each row execute function public.guard_account_lifecycle_mutation();
create function public.staff_shop_counter_allowed(p_old jsonb,p_new jsonb) returns boolean
language sql volatile security definer set search_path='' as $$
 select pg_trigger_depth()>1 and exists (
   select 1 from public.staff_shop_counter_context c
   join public.shop_orders o on o.id=c.order_id
   join public.shop_products p on p.id=c.product_id and p.club_id is not distinct from o.club_id
   where c.transaction_id=txid_current() and o.user_id=auth.uid()
     and ((c.delta<0 and o.status='pending' and o.inventory_reserved)
       or (c.delta>0 and o.status='cancelled' and not o.inventory_reserved))
     and exists(select 1 from jsonb_array_elements(o.items) item
       where coalesce(nullif(item->>'product_id',''),nullif(item->'product'->>'id',''))::uuid=c.product_id
       and (item->>'quantity')::integer=abs(c.delta))
     and (p_old is null or (p_old->>'id'=c.product_id::text
       and p_old->>'club_id' is not distinct from o.club_id::text
       and (p_new->>'stock')::integer-(p_old->>'stock')::integer=c.delta
       and p_new-'stock'=p_old-'stock'))
 );
$$;
revoke all on function public.staff_shop_counter_allowed(jsonb,jsonb) from public,anon,authenticated,service_role;
-- Patch only the counter envelope: original price/quantity/tenant/stock checks
-- and restore-once behavior remain. Temp-table trigger attachment cannot forge it.
do $$ declare v_def text; begin
 v_def:=pg_get_functiondef('public.rs_decrement_stock_on_order()'::regprocedure);
 v_def:=regexp_replace(v_def,'\mbegin\M',E'begin\n  if TG_TABLE_SCHEMA<>''public'' or TG_TABLE_NAME<>''shop_orders'' or TG_WHEN<>''AFTER'' or TG_OP<>''INSERT'' then raise exception ''SHOP_COUNTER_TRIGGER_REQUIRED'' using errcode=''42501''; end if;','i');
 v_def:=replace(v_def,'    update public.shop_products', $patch$    insert into public.staff_shop_counter_context(transaction_id,order_id,product_id,delta)
      select txid_current(),o.id,v_product_id,-v_quantity from public.shop_orders o
      where o.id=new.id and o.items=new.items and o.user_id=new.user_id
        and o.club_id is not distinct from new.club_id and o.status='pending' and o.inventory_reserved;
    if not found then raise exception 'SHOP_COUNTER_ORDER_REQUIRED' using errcode='42501'; end if;
    update public.shop_products$patch$);
 v_def:=replace(v_def,'    if v_updated_product_id is null then', $patch$    delete from public.staff_shop_counter_context where transaction_id=txid_current() and order_id=new.id and product_id=v_product_id;
    if v_updated_product_id is null then$patch$);
 execute v_def;
 v_def:=pg_get_functiondef('public.restock_cancelled_shop_order()'::regprocedure);
 v_def:=replace(v_def,'  v_quantity integer;','  v_quantity integer; v_stock_updated boolean;');
 v_def:=regexp_replace(v_def,'\mbegin\M',E'begin\n  if TG_TABLE_SCHEMA<>''public'' or TG_TABLE_NAME<>''shop_orders'' or TG_WHEN<>''AFTER'' or TG_OP<>''UPDATE'' then raise exception ''SHOP_COUNTER_TRIGGER_REQUIRED'' using errcode=''42501''; end if;','i');
 -- Insert the stock-result capture first, so context INSERT's own FOUND check
 -- remains independent from the original UPDATE's required product check.
 v_def:=replace(v_def,'      if not found then', $patch$      v_stock_updated:=found;
      delete from public.staff_shop_counter_context where transaction_id=txid_current() and order_id=new.id and product_id=v_product_id;
      if not v_stock_updated then$patch$);
 v_def:=replace(v_def,'      update public.shop_products as product', $patch$      insert into public.staff_shop_counter_context(transaction_id,order_id,product_id,delta)
        select txid_current(),o.id,v_product_id,v_quantity from public.shop_orders o
        where o.id=new.id and o.items=old.items and o.items=new.items and o.user_id=old.user_id
          and o.club_id is not distinct from old.club_id and o.status='cancelled' and not o.inventory_reserved;
      if not found then raise exception 'SHOP_COUNTER_ORDER_REQUIRED' using errcode='42501'; end if;
      update public.shop_products as product$patch$);
 execute v_def;
end; $$;
revoke all on function public.rs_decrement_stock_on_order(),public.restock_cancelled_shop_order() from public,anon,authenticated,service_role;

-- Ticket accounting is also a supporter path. Only the installed AFTER
-- trigger can bind a stored own-account ticket to its original match. The
-- receipt authorizes the canonical aggregate counter and timestamp alone.
create table public.staff_ticket_counter_context (
 transaction_id bigint not null,ticket_id uuid not null,match_id uuid not null,
 ticket_state jsonb not null,primary key(transaction_id,ticket_id,match_id)
);
alter table public.staff_ticket_counter_context enable row level security;
revoke all on public.staff_ticket_counter_context from public,anon,authenticated,service_role;
create policy account_lifecycle_access on public.staff_ticket_counter_context as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed());
create trigger account_lifecycle_statement_guard before insert or update or delete on public.staff_ticket_counter_context for each statement execute function public.guard_account_lifecycle_mutation();
create trigger account_lifecycle_mutation_guard before insert or update or delete on public.staff_ticket_counter_context for each row execute function public.guard_account_lifecycle_mutation();
create function public.staff_ticket_counter_allowed(p_old jsonb,p_new jsonb) returns boolean
language sql volatile security definer set search_path='' as $$
 select pg_trigger_depth()>1 and exists(
  select 1 from public.staff_ticket_counter_context c
  join public.tickets t on t.id=c.ticket_id and to_jsonb(t)=c.ticket_state
  join public.matches m on m.id=c.match_id and t.match_id=m.id and t.club_id=m.club_id
  where c.transaction_id=txid_current() and t.user_id=auth.uid()
   and t.club_id=nullif(public.requesting_club_id(),'')::bigint
   and t.status in ('pending','valid','used','cancelled','voided','refunded')
   and ((p_old is null and p_new is null) or (
    p_old->>'id'=m.id::text and p_new->>'id'=m.id::text
    and p_old-'sold_count'-'updated_at'=p_new-'sold_count'-'updated_at'
    and (p_new->>'updated_at')::timestamptz=timezone('utc',now())
    and (p_new->>'sold_count')::integer=(select count(*)::integer from public.tickets counted where counted.match_id=m.id and counted.status in ('pending','valid','used'))))
 );
$$;
revoke all on function public.staff_ticket_counter_allowed(jsonb,jsonb) from public,anon,authenticated,service_role;
-- Retain the original aggregate UPDATE/DELETE behavior. Only real own-ticket
-- INSERT/UPDATE adds a narrowly bound envelope; staff/service accounting keeps
-- its separate authority rather than pretending to be the ticket owner.
do $$ declare v_def text; begin
 v_def:=pg_get_functiondef('public.refresh_match_ticket_sales()'::regprocedure);
 if strpos(v_def,'  if v_new_match_id is not null then')=0 or strpos(v_def,'  if v_old_match_id is not null')=0 then
  raise exception 'STAFF_TICKET_COUNTER_SOURCE_MISMATCH'; end if;
 v_def:=replace(v_def,'  if v_new_match_id is not null then',$patch$
  if tg_table_schema<>'public' or tg_table_name<>'tickets' or tg_when<>'AFTER' or tg_level<>'ROW' then
   raise exception 'TICKET_COUNTER_TRIGGER_REQUIRED' using errcode='42501'; end if;
  if v_new_match_id is not null then
    if auth.role()='authenticated' and current_setting('role',true) is distinct from 'service_role'
      and new.user_id=auth.uid() then
     if tg_op='UPDATE' and (new.id,new.user_id,new.club_id,new.match_id) is distinct from (old.id,old.user_id,old.club_id,old.match_id) then
      raise exception 'TICKET_COUNTER_IDENTITY_REQUIRED' using errcode='42501'; end if;
     insert into public.staff_ticket_counter_context(transaction_id,ticket_id,match_id,ticket_state)
      select txid_current(),t.id,m.id,to_jsonb(t) from public.tickets t join public.matches m on m.id=t.match_id and m.club_id=t.club_id
      where t.id=new.id and to_jsonb(t)=to_jsonb(new) and t.user_id=auth.uid()
       and t.club_id=nullif(public.requesting_club_id(),'')::bigint;
     if not found then raise exception 'TICKET_COUNTER_RECORD_REQUIRED' using errcode='42501'; end if;
    end if;
$patch$);
 v_def:=replace(v_def,'  if v_old_match_id is not null',$patch$
  delete from public.staff_ticket_counter_context where transaction_id=txid_current() and ticket_id=case when tg_op<>'DELETE' then new.id else old.id end;
  if v_old_match_id is not null$patch$);
 execute v_def;
end $$;
revoke all on function public.refresh_match_ticket_sales() from public,anon,authenticated,service_role;

-- This guard applies only to explicit staff configuration tables below. Service
-- jobs retain existing role/lease/tenant boundaries. Supporter records are absent.
create function public.guard_staff_configuration_mutation() returns trigger
language plpgsql volatile security definer set search_path='' as $$
begin
  if auth.role()='authenticated' and current_setting('role',true) is distinct from 'service_role' then
    perform public.assert_account_active();
    if TG_TABLE_SCHEMA='public' and TG_TABLE_NAME='shop_products' and TG_OP='UPDATE'
       and public.staff_shop_counter_allowed(case when TG_LEVEL='ROW' then to_jsonb(old) end,case when TG_LEVEL='ROW' then to_jsonb(new) end) then
      if TG_LEVEL='STATEMENT' then return null; end if;
      return new;
    end if;
    if TG_TABLE_SCHEMA='public' and TG_TABLE_NAME='matches' and TG_OP='UPDATE'
       and public.staff_ticket_counter_allowed(case when TG_LEVEL='ROW' then to_jsonb(old) end,case when TG_LEVEL='ROW' then to_jsonb(new) end) then
      if TG_LEVEL='STATEMENT' then return null; end if;
      return new;
    end if;
    perform public.assert_staff_step_up();
    if TG_TABLE_SCHEMA='public' and TG_TABLE_NAME in ('shop_products','membership_packages','livescore_competition_sources') then
      perform public.assert_staff_commercial_role(case when TG_LEVEL='STATEMENT' then null when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end,TG_LEVEL='ROW');
    end if;
    perform public.assert_staff_configuration_role(case when TG_LEVEL='STATEMENT' then null when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end,TG_LEVEL='ROW');
    if TG_LEVEL='ROW' and TG_TABLE_SCHEMA='public' and TG_TABLE_NAME in ('shop_products','membership_packages')
       and (TG_OP='INSERT' or (TG_OP='UPDATE' and ((to_jsonb(new)->'partner_id') is distinct from (to_jsonb(old)->'partner_id') or (to_jsonb(new)->'club_id') is distinct from (to_jsonb(old)->'club_id')))) then
      perform public.assert_staff_commercial_partner(to_jsonb(new));
    end if;
  end if;
  if TG_LEVEL='STATEMENT' then return null; end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function public.guard_staff_configuration_mutation() from public,anon,authenticated,service_role;
do $$ declare v_table text; v_command text; begin
  foreach v_table in array array[
    'public.matches','public.news_articles','public.quick_actions','public.partners','public.partner_services',
    'public.platform_features','public.platform_feature_channels','public.platform_feature_rules','public.platform_content_blocks',
    'public.app_config','public.club_app_config','public.membership_packages','public.shop_products','public.home_banners','public.livescore_competition_sources',
    'football.competitions','football.seasons','football.fixtures','football.prediction_markets','public.prediction_supported_competitions'] loop
    if to_regclass(v_table) is null then raise exception 'STAFF_PROTECTED_TABLE_MISSING: %',v_table; end if;
    execute format('create trigger staff_step_up_statement before insert or update or delete on %s for each statement execute function public.guard_staff_configuration_mutation()',v_table);
    execute format('create trigger staff_step_up_row before insert or update or delete on %s for each row execute function public.guard_staff_configuration_mutation()',v_table);
    foreach v_command in array array['INSERT','UPDATE','DELETE'] loop
      execute format('create policy %I on %s as restrictive for %s to authenticated %s',
        'staff_step_up_'||lower(v_command),v_table,v_command,
        case v_command when 'INSERT' then 'with check (public.staff_step_up_allowed())'
          when 'DELETE' then 'using (public.staff_step_up_allowed())'
          else 'using (public.staff_step_up_allowed()) with check (public.staff_step_up_allowed())' end);
    end loop;
  end loop;
end; $$;

-- Staff selection may use any current assignment; supporter read policies keep
-- preferred-club semantics. Existing stricter table write predicates remain.
-- Current-role callers already have an explicit column projection behind the
-- own-or-current-super-admin read policy. Add only its missing revocation field:
-- no table-wide SELECT or new authority-disclosing read policy is introduced.
grant select (revoked_at) on public.admin_role_assignments to authenticated;
alter policy matches_admin_insert on public.matches with check (public.is_club_admin(club_id));
alter policy matches_admin_update on public.matches using (public.is_club_admin(club_id)) with check (public.is_club_admin(club_id));
create policy matches_admin_delete on public.matches for delete to authenticated using (public.is_club_admin(club_id));
alter policy news_articles_admin_all on public.news_articles using (auth.role()='authenticated' and public.is_club_admin(club_id)) with check (auth.role()='authenticated' and public.is_club_admin(club_id));
-- Replace obsolete metadata authority, preserving global-only banner writes.
alter policy "Admins can manage home banners" on public.home_banners using (public.is_admin_user()) with check (public.is_admin_user());

-- These actual tables were service-written by the web. Caller-JWT writes now
-- receive explicit table grants behind existing read and narrow staff policies.
-- Preserve upstream read projections and approval/classification columns.
-- Clients may edit content/configuration only; provider approval fields stay
-- outside every authenticated INSERT/UPDATE grant.
revoke insert,update on public.membership_packages,public.shop_products,public.home_banners,public.matches,public.news_articles from authenticated;
-- Preserve original public-safe SELECT projections. Actual optimistic editor
-- receipts also require these non-authority timestamps; no private read grant.
grant select (updated_at) on public.matches to authenticated;
grant select (created_at,updated_at) on public.shop_products to authenticated;
grant insert (id,club_id,partner_id,tier,title,subtitle,description,benefits,sort_order,is_active,annual_price,price) on public.membership_packages to authenticated;
grant update (club_id,partner_id,tier,title,subtitle,description,benefits,sort_order,is_active,annual_price,price) on public.membership_packages to authenticated;
grant insert (id,club_id,partner_id,name,subtitle,description,category,price,stock,image_url,sizes,available_sizes,is_active,is_new,badge_label,collection,sort_order,product_id,product_type,currency,commerce_mode,enquiry_phone) on public.shop_products to authenticated;
grant update (club_id,partner_id,name,subtitle,description,category,price,stock,image_url,sizes,available_sizes,is_active,is_new,badge_label,collection,sort_order,product_id,product_type,currency,commerce_mode,enquiry_phone) on public.shop_products to authenticated;
grant insert (id,club_id,title,subtitle,badge_label,cta_label,route,image_url,sort_order,is_active,distribution) on public.home_banners to authenticated;
grant update (club_id,title,subtitle,badge_label,cta_label,route,image_url,sort_order,is_active,distribution) on public.home_banners to authenticated;
grant delete on public.membership_packages,public.shop_products,public.home_banners,public.matches,public.news_articles to authenticated;
create policy staff_commercial_config on public.membership_packages for all to authenticated
 using (public.is_admin_user() or exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role='club_admin' and a.club_id=membership_packages.club_id))
 with check (public.is_admin_user() or exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role='club_admin' and a.club_id=membership_packages.club_id));
create policy staff_commercial_config on public.shop_products for all to authenticated
 using (public.is_admin_user() or exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role='club_admin' and a.club_id=shop_products.club_id))
 with check (public.is_admin_user() or exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role='club_admin' and a.club_id=shop_products.club_id));

-- Actual caller-JWT CMS/fixture writers previously depended on service ACLs.
-- Their existing scoped CMS predicates remain; shared football data is global.
grant insert (id,club_id,partner_id,home_team,away_team,competition,venue,match_date,kickoff_time,sale_starts_at,is_on_sale,ticket_general_price,ticket_vip_price,capacity,image_url,match_status,home_score,away_score,live_minute,match_summary,is_featured,fixture_id,roster,live_stats,live_events) on public.matches to authenticated;
grant update (club_id,partner_id,home_team,away_team,competition,venue,match_date,kickoff_time,sale_starts_at,is_on_sale,ticket_general_price,ticket_vip_price,capacity,image_url,match_status,home_score,away_score,live_minute,match_summary,is_featured,fixture_id,roster,live_stats,live_events) on public.matches to authenticated;
grant insert (id,club_id,title,subtitle,body,category,image_url,is_published,published_at,is_featured,sort_order,author_name,source_url) on public.news_articles to authenticated;
grant update (club_id,title,subtitle,body,category,image_url,is_published,published_at,is_featured,sort_order,author_name,source_url) on public.news_articles to authenticated;
grant select,insert,update,delete on football.competitions,football.seasons,football.fixtures to authenticated;
create policy staff_global_write on football.competitions for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy staff_global_write on football.seasons for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
create policy staff_global_write on football.fixtures for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());

-- Exact additional active Web handlers: shared markets are global-only;
-- LiveScore sources carry their own authoritative row club, with club_admin only.
grant select,insert,update,delete on football.prediction_markets,public.livescore_competition_sources to authenticated;
create policy staff_global_write on football.prediction_markets for all to authenticated using (public.is_admin_user()) with check (public.is_admin_user());
alter policy livescore_competition_sources_admin_write on public.livescore_competition_sources
 using (public.is_admin_user() or exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role='club_admin' and a.club_id=livescore_competition_sources.club_id))
 with check (public.is_admin_user() or exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role='club_admin' and a.club_id=livescore_competition_sources.club_id));

-- Human staff role changes require fresh assurance. Account closure uses its
-- existing service-only adapter; no human lifecycle exception is introduced.
create function public.guard_staff_role_mutation() returns trigger
language plpgsql volatile security definer set search_path='' as $$
declare v_assignment uuid;
begin
  if auth.role()='authenticated' and current_setting('role',true) is distinct from 'service_role' then
    perform public.assert_account_active(); perform public.assert_staff_step_up();
    select a.id into v_assignment from public.admin_role_assignments a where a.user_id=auth.uid() and a.is_active and a.revoked_at is null and a.role in ('admin','super_admin') order by a.id limit 1 for share;
    perform public.assert_account_active(); perform public.assert_staff_step_up();
    if v_assignment is null then
      raise exception 'STAFF_GLOBAL_ADMIN_REQUIRED' using errcode='42501';
    end if;
  end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function public.guard_staff_role_mutation() from public,anon,authenticated,service_role;
create trigger staff_step_up_role before insert or update or delete on public.admin_role_assignments
for each row execute function public.guard_staff_role_mutation();

-- Exact governed caller RPCs retain their original public identities, grants,
-- account/tenant/role guards and historical behavior. Nothing is renamed or
-- exposed. All existing admin reauthorization points also recheck assurance.
do $$ declare v_signature text; v_definition text; begin
  foreach v_signature in array array[
    'public.predict_admin_settings(bigint,boolean,integer)',
    'public.predict_admin_prepare(bigint,uuid,text)',
    'public.predict_admin_confirm_result(uuid,integer,integer,text)',
    'public.predict_admin_settle(uuid,text)',
    'public.admin_update_platform_feature_if_unchanged(uuid,timestamptz,bigint,jsonb,uuid)',
    'public.fet_admin_update_reward_redemption(uuid,text,text,text,text)'] loop
    v_definition:=pg_get_functiondef(v_signature::regprocedure);
    v_definition:=regexp_replace(v_definition,'\mbegin\M','begin'||E'\n  perform public.assert_staff_step_up();','i');
    if v_signature like 'public.predict_admin_%' then
      v_definition:=regexp_replace(v_definition,'(perform public\.predict_require_admin\([^;]+;)',E'\\1\n  perform public.assert_staff_step_up();','g');
      -- These writes can wait on unique constraints/entry rows after the admin
      -- lock. An additional post-write check rolls the entire call back if expired.
      v_definition:=regexp_replace(v_definition,'\mreturn\M',E'perform public.assert_staff_step_up();\n  return','gi');
    elsif v_signature like 'public.admin_update_platform_%' then
      v_definition:=regexp_replace(v_definition,'\mbegin\M',E'begin\n  if p_actor_id is distinct from auth.uid() then raise exception ''STAFF_ACTOR_MISMATCH'' using errcode=''42501''; end if;\n  perform public.assert_staff_configuration_role(jsonb_build_object(''club_id'',p_club_id),false);','i');
      v_definition:=regexp_replace(v_definition,'(for update;)',E'\\1\n  perform public.assert_staff_configuration_role(jsonb_build_object(''club_id'',p_club_id),true);','gi');
      v_definition:=regexp_replace(v_definition,'\mreturn\M',E'perform public.assert_staff_configuration_role(jsonb_build_object(''club_id'',p_club_id),true);\n  return','gi');
    elsif v_signature like 'public.fet_admin_%' then
      v_definition:=regexp_replace(v_definition,'(update public\.fet_reward_redemptions)',E'perform public.assert_staff_step_up();\n  \\1','i');
      v_definition:=regexp_replace(v_definition,'\mreturn\M',E'perform public.assert_staff_step_up();\n  return','gi');
    end if;
    execute v_definition;
  end loop;
end; $$;
