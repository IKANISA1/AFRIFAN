-- Original GLOBAL operator commands; cron remains an independent service caller.
begin;
-- A global operation has no tenant target. Extend only the existing private
-- global proof path; every non-global path still requires its real live club.
do $$ declare d text; begin
 d:=pg_get_functiondef('public.lock_verified_staff_provider_actor(uuid,bigint,boolean)'::regprocedure);
 if position('perform 1 from public.african_football_clubs where id=p_club and is_active for share;' in d)=0 then raise exception 'GLOBAL_PROOF_PATCH_INPUT_CHANGED'; end if;
 d:=replace(d,'perform 1 from public.african_football_clubs where id=p_club and is_active for share;'||chr(10)||' if not found then raise exception ''PROVIDER_CLUB_UNAVAILABLE'' using errcode=''42501''; end if;',
 'if p_club is null and p_require_global is true then null; else'||chr(10)||' perform 1 from public.african_football_clubs where id=p_club and is_active for share;'||chr(10)||' if not found then raise exception ''PROVIDER_CLUB_UNAVAILABLE'' using errcode=''42501''; end if; end if;');
 execute d;
 d:=pg_get_functiondef('public.capture_verified_staff_provider_proof(bigint,boolean)'::regprocedure);
 if position('p_club_id is null or p_club_id<=0 or p_require_global is null' in d)=0 then raise exception 'GLOBAL_PROOF_PATCH_INPUT_CHANGED'; end if;
 execute replace(d,'p_club_id is null or p_club_id<=0 or p_require_global is null','(p_club_id is null and p_require_global is distinct from true) or p_club_id<=0 or p_require_global is null');
end $$;
create table public.manual_football_sync_commands(
 operation_id uuid primary key check(operation_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
 actor_id uuid not null references auth.users(id) on delete restrict,
 scope text not null default 'global' check(scope='global'), arguments jsonb not null, arguments_sha256 text not null,
 snapshot jsonb not null, snapshot_sha256 text not null, admitted_at timestamptz not null default clock_timestamp(),
 lease_mode text not null default 'dispatch' check(lease_mode in('dispatch','reconcile_storage')),
 state text not null default 'admitted' check(state in('admitted','processing','completed','unknown','blocked')),
 current_proof_id uuid not null, used_leases uuid[] not null default array[]::uuid[], lease_token uuid, lease_proof_id uuid, lease_until timestamptz, result jsonb,
 check((lease_token is null)=(lease_until is null)),check(lease_token is null or lease_proof_id is not null),
 check(arguments_sha256 ~ '^[0-9a-f]{64}$' and snapshot_sha256 ~ '^[0-9a-f]{64}$')
);
create table public.manual_football_sync_proofs(
 operation_id uuid not null references public.manual_football_sync_commands(operation_id) on delete restrict,
 proof_id uuid not null default gen_random_uuid(), proof jsonb not null, admitted_at timestamptz not null default clock_timestamp(),
 primary key(operation_id,proof_id),unique(operation_id,proof)
);
alter table public.manual_football_sync_commands add foreign key(operation_id,current_proof_id) references public.manual_football_sync_proofs(operation_id,proof_id) deferrable initially deferred;
alter table public.manual_football_sync_commands add foreign key(operation_id,lease_proof_id) references public.manual_football_sync_proofs(operation_id,proof_id) deferrable initially deferred;
create table public.manual_football_sync_requests(
 request_id uuid primary key default gen_random_uuid(),operation_id uuid not null references public.manual_football_sync_commands(operation_id) on delete restrict,
 lease_token uuid not null,lease_proof_id uuid not null,url text not null check(length(url)<=4096),url_sha256 text not null,
 attempt integer not null check(attempt between 1 and 3),state text not null check(state in('started','accepted','rejected','unknown')),
 started_at timestamptz not null default clock_timestamp(),completed_at timestamptz,
 response_status integer check(response_status between 100 and 599),response_headers jsonb,response_body text,
 provider_json jsonb,content_sha256 text,byte_length integer,content_type text,expected_owner text,observed_object_id uuid,source_request_id uuid references public.manual_football_sync_requests(request_id) on delete restrict,unique(operation_id,url_sha256,attempt),
 foreign key(operation_id,lease_proof_id) references public.manual_football_sync_proofs(operation_id,proof_id)
);
-- An uncertain actual GET cannot be reset by a new operation, actor or proof.
create unique index manual_football_sync_uncertain_request on public.manual_football_sync_requests(url_sha256) where state in('started','unknown');
do $$ declare t text; begin
 foreach t in array array['manual_football_sync_commands','manual_football_sync_proofs','manual_football_sync_requests'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
 end loop;
end $$;
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
 select oid,conrelid::regclass::text,confrelid::regclass::text,confdeltype::text,true from pg_constraint
 where contype='f' and conrelid='public.manual_football_sync_commands'::regclass and confrelid='auth.users'::regclass on conflict(constraint_oid) do nothing;

create function public.manual_football_json_hash(p jsonb) returns text language sql immutable set search_path='' as $$
 select encode(extensions.digest(convert_to(p::text,'UTF8'),'sha256'),'hex'); $$;
create function public.manual_football_arguments(p jsonb) returns jsonb language plpgsql volatile set search_path='' as $$
declare k text;c text:=p->>'command';allowed text[]:=array['command'];v jsonb;
begin
 if jsonb_typeof(p) is distinct from 'object' or c is null or c not in('discover-leagues','register-league','sync-fixtures','sync-standings','sync-live','sync-history','download-logos','seed-leagues','status','full-sync','auto-settle') then raise exception 'FOOTBALL_ARGUMENTS_INVALID' using errcode='22023'; end if;
 allowed:=allowed||case c when 'discover-leagues' then array['search','country','id'] when 'register-league' then array['api_league_id','season_year','league_name','sync_fixtures','sync_standings','sync_live','sync_squads'] when 'sync-history' then array['league_id','season_year'] when 'seed-leagues' then array['dry_run'] else array[]::text[] end;
 if p-allowed<>'{}'::jsonb or octet_length(p::text)>2048 then raise exception 'FOOTBALL_ARGUMENTS_INVALID' using errcode='22023'; end if;
 for k,v in select key,value from jsonb_each(p) where key<>'command' loop
  if k in('id','api_league_id','league_id','season_year') then
   if jsonb_typeof(v) is distinct from 'number' or (v::text)::numeric<>trunc((v::text)::numeric) or (v::text)::numeric not between 1 and 2147483647 or (k='season_year' and (v::text)::numeric not between 1900 and 2200) then raise exception 'FOOTBALL_ARGUMENTS_INVALID' using errcode='22023';end if;
  elsif k like 'sync_%' or k='dry_run' then
   if jsonb_typeof(v) is distinct from 'boolean' then raise exception 'FOOTBALL_ARGUMENTS_INVALID' using errcode='22023';end if;
  elsif jsonb_typeof(v) is distinct from 'string' or length(trim(p->>k)) not between 1 and 160 then raise exception 'FOOTBALL_ARGUMENTS_INVALID' using errcode='22023';
  else p:=jsonb_set(p,array[k],to_jsonb(trim(p->>k))); end if;
 end loop;
 if c='register-league' and not p?'api_league_id' then raise exception 'FOOTBALL_ARGUMENTS_INVALID' using errcode='22023';end if;
 return p;
end $$;
create function public.manual_football_snapshot() returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare configs jsonb;live jsonb;logos jsonb;finished jsonb;s jsonb;
begin
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'competition_id',competition_id,'external_provider',external_provider,'external_league_id',external_league_id,'season_year',season_year,'sync_fixtures',sync_fixtures,'sync_standings',sync_standings,'sync_live',sync_live,'sync_squads',sync_squads,'is_active',is_active) order by id),'[]') into configs from public.football_sync_config where is_active;
 select coalesce(jsonb_agg(to_jsonb(f)),'[]') into live from(select id,external_fixture_id from football.fixtures where external_provider='api-football' and (status='live' or (status='finished' and updated_at>=clock_timestamp()-interval '3 hours')) order by id limit 15)f;
 select coalesce(jsonb_agg(to_jsonb(f)),'[]') into finished from(select id,home_score,away_score from football.fixtures where status='finished' and home_score is not null and away_score is not null order by id limit 5001)f;
 select coalesce(jsonb_agg(to_jsonb(l)),'[]') into logos from(
  select 'teams'::text kind,id::text id,coalesce(nullif(crest_url,''),metadata->>'api_logo') url,'teams/'||external_team_id||'.png' path from football.teams where external_provider='api-football' and external_team_id is not null and not metadata?'storage_logo_url'
  union all select 'configs',id::text,metadata->>'api_league_logo','leagues/'||external_league_id||'.png' from public.football_sync_config where is_active and not metadata?'storage_league_logo_url'
  union all select 'competitions',id::text,metadata->>'api_country_flag','flags/'||lower(country_code)||'.svg' from football.competitions where country_code is not null and not metadata?'storage_flag_url'
 )l where url is not null;
 s:=jsonb_build_object('seed_targets','[{"api_league_id": 1, "name": "FIFA World Cup 2026", "country": null, "search": null, "season_year": 2026}, {"api_league_id": 2, "name": "UEFA Champions League", "country": null, "search": null, "season_year": 2025}, {"api_league_id": 39, "name": "English Premier League", "country": null, "search": null, "season_year": 2025}, {"api_league_id": 140, "name": "La Liga", "country": null, "search": null, "season_year": 2025}, {"api_league_id": null, "name": "Rwanda Premier League", "country": "Rwanda", "search": "Premier League", "season_year": 2025}, {"api_league_id": 424, "name": "Linafoot", "country": "Congo-DR", "search": "Ligue 1", "season_year": 2025}, {"api_league_id": null, "name": "Zambia Super League", "country": "Zambia", "search": "Super League", "season_year": 2025}, {"api_league_id": null, "name": "Ghana Premier League", "country": "Ghana", "search": "Premier League", "season_year": 2025}, {"api_league_id": null, "name": "Ligue 1 Côte d''Ivoire", "country": "Ivory-Coast", "search": "Ligue 1", "season_year": 2025}, {"api_league_id": null, "name": "Kenya Premier League", "country": "Kenya", "search": "Premier League", "season_year": 2025}, {"api_league_id": null, "name": "Tanzania Premier League", "country": "Tanzania", "search": "Premier League", "season_year": 2025}, {"api_league_id": null, "name": "Uganda Premier League", "country": "Uganda", "search": "Premier League", "season_year": 2025}, {"api_league_id": null, "name": "Malawi Super League", "country": "Malawi", "search": "Super League", "season_year": 2025}]'::jsonb,'default_season_year',extract(year from clock_timestamp())::integer,'configs',configs,'live',live,'finished',finished,'logos',logos);
 if jsonb_array_length(configs)>256 or jsonb_array_length(finished)>5000 or jsonb_array_length(logos)>5000 or octet_length(s::text)>2097152 then raise exception 'FOOTBALL_TARGET_BOUND_EXCEEDED' using errcode='22023'; end if;
 return s;
end $$;
create function public.guard_manual_football_immutable() returns trigger language plpgsql set search_path='' as $$ begin
 if TG_OP='DELETE' or TG_TABLE_NAME='manual_football_sync_proofs' then raise exception 'FOOTBALL_COMMAND_IMMUTABLE';end if;
 if TG_TABLE_NAME='manual_football_sync_commands' then
  if (new.operation_id,new.actor_id,new.scope,new.arguments,new.arguments_sha256,new.snapshot,new.snapshot_sha256,new.admitted_at) is distinct from (old.operation_id,old.actor_id,old.scope,old.arguments,old.arguments_sha256,old.snapshot,old.snapshot_sha256,old.admitted_at)
   or (old.state='completed' and new is distinct from old) then raise exception 'FOOTBALL_COMMAND_IMMUTABLE';end if;
 else
  if (new.request_id,new.operation_id,new.lease_token,new.lease_proof_id,new.url,new.url_sha256,new.attempt,new.started_at,new.content_sha256,new.byte_length,new.content_type,new.expected_owner,new.source_request_id) is distinct from (old.request_id,old.operation_id,old.lease_token,old.lease_proof_id,old.url,old.url_sha256,old.attempt,old.started_at,old.content_sha256,old.byte_length,old.content_type,old.expected_owner,old.source_request_id)
   or(old.observed_object_id is not null and new.observed_object_id is distinct from old.observed_object_id) or(old.state<>'started' and not(old.state='unknown' and old.source_request_id is not null and new.state='accepted')) then raise exception 'FOOTBALL_REQUEST_IMMUTABLE';end if;
 end if;return new;
end $$;
create trigger manual_football_command_immutable before update or delete on public.manual_football_sync_commands for each row execute function public.guard_manual_football_immutable();
create trigger manual_football_proof_immutable before update or delete on public.manual_football_sync_proofs for each row execute function public.guard_manual_football_immutable();
create trigger manual_football_request_immutable before update or delete on public.manual_football_sync_requests for each row execute function public.guard_manual_football_immutable();
create function public.manual_football_receipt(c public.manual_football_sync_commands) returns jsonb language sql volatile security definer set search_path='' as $$
 select jsonb_build_object('command',jsonb_build_object('version',1,'operation_id',(c).operation_id,'actor_id',(c).actor_id,'scope','global','command',(c).arguments->>'command','arguments_sha256',(c).arguments_sha256,'snapshot_sha256',(c).snapshot_sha256,
 'state',case when exists(select 1 from public.manual_football_sync_requests where operation_id=(c).operation_id and (state='unknown' or (state='started' and (c).lease_until<=clock_timestamp()))) then 'unknown' else (c).state end),
 'requests',jsonb_build_object('accepted',count(*) filter(where r.state='accepted'),'rejected',count(*) filter(where r.state='rejected'),'unknown',count(*) filter(where r.state='unknown' or(r.state='started' and(c).lease_until<=clock_timestamp())),'started',count(*) filter(where r.state='started' and(c).lease_until>clock_timestamp())), 'result',(c).result)
 from public.manual_football_sync_requests r where r.operation_id=(c).operation_id;
$$;
create function public.manual_football_storage_recovery(c public.manual_football_sync_commands) returns boolean language sql volatile security definer set search_path='' as $$
 select exists(select 1 from public.manual_football_sync_requests where operation_id=(c).operation_id and(state='unknown' or(state='started' and(c).lease_until<=clock_timestamp())))
 and not exists(select 1 from public.manual_football_sync_requests where operation_id=(c).operation_id and(state='unknown' or(state='started' and(c).lease_until<=clock_timestamp())) and source_request_id is null);
$$;
-- Every caller enters the actor lifecycle lock before the operation lock.
-- This unlocked read is only an immutable owner hint, never authority. The
-- original command is reread and its identity checked after both locks.
create function public.lock_manual_football_sync_command(p_operation_id uuid) returns public.manual_football_sync_commands
language plpgsql security definer set search_path='' as $$
declare original_actor uuid;c public.manual_football_sync_commands;
begin
 select actor_id into original_actor from public.manual_football_sync_commands where operation_id=p_operation_id;
 if original_actor is null then raise exception 'FOOTBALL_COMMAND_UNAVAILABLE' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(original_actor::text,21000));
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,31000));
 select * into c from public.manual_football_sync_commands where operation_id=p_operation_id for update;
 if c.operation_id is null or c.actor_id is distinct from original_actor then raise exception 'FOOTBALL_COMMAND_BINDING_MISMATCH' using errcode='42501';end if;
 return c;
end $$;
create function public.admit_manual_football_sync(p_operation_id uuid,p_arguments jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;v_proof jsonb;pid uuid;s jsonb;a jsonb;
begin
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'FOOTBALL_OPERATION_REQUIRED' using errcode='22023';end if;
 a:=public.manual_football_arguments(p_arguments);v_proof:=public.capture_verified_staff_provider_proof(null,true);
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,31000));
 select * into c from public.manual_football_sync_commands where operation_id=p_operation_id for update;
 if found then
  if c.actor_id is distinct from auth.uid() or c.arguments is distinct from a then raise exception 'FOOTBALL_COMMAND_BINDING_MISMATCH';end if;
  perform public.assert_verified_staff_provider_proof(c.actor_id,null,true,v_proof);
  if c.state='completed' or ((c.state='unknown' or exists(select 1 from public.manual_football_sync_requests where operation_id=p_operation_id and (state='unknown' or(state='started' and c.lease_until<=clock_timestamp())))) and not public.manual_football_storage_recovery(c)) then return public.manual_football_receipt(c);end if;
 else
  s:=public.manual_football_snapshot();pid:=gen_random_uuid();
  insert into public.manual_football_sync_commands(operation_id,actor_id,arguments,arguments_sha256,snapshot,snapshot_sha256,current_proof_id)
   values(p_operation_id,auth.uid(),a,public.manual_football_json_hash(a),s,public.manual_football_json_hash(s),pid) returning * into c;
 end if;
 if (select count(*) from public.manual_football_sync_proofs where operation_id=p_operation_id)>=32 and not exists(select 1 from public.manual_football_sync_proofs where operation_id=p_operation_id and manual_football_sync_proofs.proof=v_proof) then raise exception 'FOOTBALL_PROOF_BOUND_EXCEEDED';end if;
 insert into public.manual_football_sync_proofs(operation_id,proof_id,proof) values(p_operation_id,coalesce(pid,gen_random_uuid()),v_proof) on conflict(operation_id,proof) do nothing;
 select proof_id into pid from public.manual_football_sync_proofs where operation_id=p_operation_id and manual_football_sync_proofs.proof=v_proof;
 update public.manual_football_sync_commands set current_proof_id=pid where operation_id=p_operation_id returning * into c;
 perform public.assert_verified_staff_provider_proof(c.actor_id,null,true,v_proof);
 return public.manual_football_receipt(c)||jsonb_build_object('dispatch_proof_id',pid);
end $$;
create function public.recover_manual_football_sync(p_operation_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;begin
 perform public.capture_verified_staff_provider_proof(null,true);
 select * into c from public.manual_football_sync_commands where operation_id=p_operation_id;
 if not found then return jsonb_build_object('command',jsonb_build_object('version',1,'operation_id',p_operation_id,'actor_id',auth.uid(),'scope','global','state','not_admitted'),'requests',null,'result',null);end if;
 if c.actor_id is distinct from auth.uid() then raise exception 'FOOTBALL_COMMAND_BINDING_MISMATCH';end if;
 return public.manual_football_receipt(c);
end $$;
create function public.assert_manual_football_authority(c public.manual_football_sync_commands,p_lease uuid) returns void language plpgsql security definer set search_path='' as $$
declare v_proof jsonb;begin
 if auth.role() is distinct from 'service_role' or current_setting('role',true) not in('service_role','supabase_storage_admin') then raise exception 'FOOTBALL_SERVICE_REQUIRED' using errcode='42501';end if;
 if (c).state<>'processing' or (c).lease_token is distinct from p_lease or (c).lease_until<=clock_timestamp() then raise exception 'FOOTBALL_LEASE_LOST' using errcode='42501';end if;
 select p.proof into v_proof from public.manual_football_sync_proofs p where operation_id=(c).operation_id and proof_id=(c).lease_proof_id;
 perform public.assert_verified_staff_provider_proof((c).actor_id,null,true,v_proof);
 if (c).lease_until<=clock_timestamp() then raise exception 'FOOTBALL_LEASE_LOST' using errcode='42501';end if;
end $$;
create function public.assert_manual_football_sync(p_operation_id uuid,p_lease_token uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;begin
 c:=public.lock_manual_football_sync_command(p_operation_id);
 perform public.assert_manual_football_authority(c,p_lease_token);return jsonb_build_object('allowed',true);
end $$;
create function public.claim_manual_football_sync(p_operation_id uuid,p_lease_token uuid,p_proof_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;v_proof jsonb;deadline timestamptz;mode text:='dispatch';
begin
 if auth.role() is distinct from 'service_role' or current_setting('role',true) is distinct from 'service_role' then raise exception 'FOOTBALL_SERVICE_REQUIRED' using errcode='42501';end if;
 c:=public.lock_manual_football_sync_command(p_operation_id);
 if c.state='completed' or(c.state<>'unknown' and c.lease_token is not null and c.lease_until>clock_timestamp()) then return jsonb_build_object('claimed',false);end if;
 if exists(select 1 from public.manual_football_sync_requests where operation_id=p_operation_id and state in('started','unknown')) then
  if not public.manual_football_storage_recovery(c) then update public.manual_football_sync_commands set state='unknown' where operation_id=p_operation_id;return jsonb_build_object('claimed',false);end if;
  mode:='reconcile_storage';update public.manual_football_sync_requests set state='unknown' where operation_id=p_operation_id and state='started';
 end if;
 if p_lease_token is null or p_lease_token::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' or p_lease_token=any(c.used_leases) then raise exception 'FOOTBALL_LEASE_REUSE' using errcode='42501';end if;
 select p.proof into v_proof from public.manual_football_sync_proofs p where operation_id=p_operation_id and proof_id=p_proof_id;
 if v_proof is null then raise exception 'FOOTBALL_ORIGINAL_PROOF_REQUIRED' using errcode='42501';end if;
 perform public.assert_verified_staff_provider_proof(c.actor_id,null,true,v_proof);
 deadline:=least((v_proof->>'expires_at')::timestamptz,clock_timestamp()+interval '4 minutes');
 update public.manual_football_sync_commands set state='processing',lease_mode=mode,used_leases=array_append(used_leases,p_lease_token),lease_token=p_lease_token,lease_proof_id=p_proof_id,lease_until=deadline where operation_id=p_operation_id returning * into c;
 perform public.assert_manual_football_authority(c,p_lease_token);
 return jsonb_build_object('claimed',true,'operation_id',p_operation_id,'actor_id',c.actor_id,'scope','global','lease_token',p_lease_token,'lease_proof_id',p_proof_id,'deadline_at',deadline,'arguments',c.arguments,'snapshot',c.snapshot,'mode',mode,'recovery_uploads',case when mode='reconcile_storage' then (select jsonb_agg(jsonb_build_object('request_id',request_id,'path',substr(url,length('storage:football-assets/')+1),'content_sha256',content_sha256,'byte_length',byte_length,'content_type',content_type)) from public.manual_football_sync_requests where operation_id=p_operation_id and state='unknown') else '[]'::jsonb end);
end $$;

create function public.manual_football_url_decode(p text) returns text language plpgsql immutable set search_path='' as $$
declare i integer:=1;b bytea:=''::bytea;v text;begin
 while i<=length(p) loop
  v:=substr(p,i,1);
  if v='%' then b:=b||decode(substr(p,i+1,2),'hex');i:=i+3;
  else b:=b||convert_to(case when v='+' then ' ' else v end,'UTF8');i:=i+1;end if;
 end loop;return convert_from(b,'UTF8');
end $$;
create function public.assert_manual_football_request(c public.manual_football_sync_commands,p_url text) returns void language plpgsql security definer set search_path='' as $$
declare path text;query text;params jsonb:='{}';pair text;key text;value text;cmd text:=(c).arguments->>'command';a jsonb:=(c).arguments;cfg jsonb;valid boolean:=false;league text;season text;
begin
 if p_url like 'storage:football-assets/%' then
  if cmd='download-logos' and exists(select 1 from jsonb_array_elements((c).snapshot->'logos')l,public.manual_football_sync_requests r where l->>'path'=substr(p_url,length('storage:football-assets/')+1) and r.operation_id=(c).operation_id and r.url=l->>'url' and r.state='accepted' and r.response_body is not null) then return;end if;
  raise exception 'FOOTBALL_REQUEST_TARGET_MISMATCH' using errcode='42501';end if;
 if length(p_url)>4096 or p_url !~ '^https://[^[:space:]#]+$' then raise exception 'FOOTBALL_REQUEST_TARGET_MISMATCH' using errcode='42501';end if;
 if p_url not like 'https://v3.football.api-sports.io/%' then
  if cmd='download-logos' and p_url ~ '^https://(media[.]api-sports[.]io|media-3[.]api-sports[.]io|media[.]api-football[.]com)/' and exists(select 1 from jsonb_array_elements((c).snapshot->'logos')l where l->>'url'=p_url) then return;end if;
  raise exception 'FOOTBALL_REQUEST_TARGET_MISMATCH' using errcode='42501';end if;
 path:=split_part(substr(p_url,length('https://v3.football.api-sports.io/')+1),'?',1);query:=split_part(p_url,'?',2);
 foreach pair in array string_to_array(query,'&') loop
  if pair='' then continue;end if;
  key:=public.manual_football_url_decode(split_part(pair,'=',1));value:=public.manual_football_url_decode(substr(pair,position('=' in pair)+1));
  if params?key then raise exception 'FOOTBALL_REQUEST_TARGET_MISMATCH' using errcode='42501';end if;params:=params||jsonb_build_object(key,value);
 end loop;
 if path='status' then valid:=cmd='status' and params='{}';
 elsif path='leagues' then
  if cmd='discover-leagues' then valid:=params=jsonb_strip_nulls(jsonb_build_object('search',a->>'search','country',a->>'country','id',a->>'id'));
  elsif cmd='register-league' then valid:=params=jsonb_build_object('id',a->>'api_league_id');
  elsif cmd='seed-leagues' then -- Seed requests are the existing finite catalog or IDs returned by its discovery.
   valid:= ((select count(*) from jsonb_object_keys(params))=1 and exists(select 1 from jsonb_array_elements((c).snapshot->'seed_targets')t where t->>'api_league_id'=params->>'id' or(t->>'country' is not null and t->>'country'=params->>'country')))
    or((select count(*) from jsonb_object_keys(params))=1 and params?'id' and exists(select 1 from public.manual_football_sync_requests r,jsonb_path_query(r.provider_json,'$.response[*].league.id')v where r.operation_id=(c).operation_id and r.state='accepted' and v#>>'{}'=params->>'id'));
  end if;
 elsif path in('fixtures/statistics','fixtures/events','fixtures/lineups') then
  valid:=cmd in('sync-live','full-sync') and params-array['fixture']='{}' and exists(select 1 from jsonb_array_elements((c).snapshot->'live')f where f->>'external_fixture_id'=params->>'fixture');
 elsif path in('fixtures','teams','standings') then
  league:=params->>'league';season:=params->>'season';
  if params-array['league','season','status']<>'{}' or league is null or season is null then valid:=false;
  else
   for cfg in select target.value from jsonb_array_elements((c).snapshot->'configs') as target(value) loop
    if cfg->>'external_league_id'=league and cfg->>'external_provider'='api-football' and cfg->>'is_active'='true' and
     ((cmd='sync-history' and (not a?'league_id' or a->>'league_id'=league) and season=coalesce(a->>'season_year',cfg->>'season_year') and path='fixtures' and params->>'status'='FT-AET-PEN-AWD-WO')
      or(cmd in('sync-fixtures','full-sync') and cfg->>'sync_fixtures'='true' and season=cfg->>'season_year' and path in('fixtures','teams') and not params?'status')
      or(cmd in('sync-standings','full-sync') and cfg->>'sync_standings'='true' and season=cfg->>'season_year' and path='standings' and not params?'status')) then
     perform 1 from public.football_sync_config sc where sc.id=(cfg->>'id')::uuid and jsonb_build_object('id',sc.id,'competition_id',sc.competition_id,'external_provider',sc.external_provider,'external_league_id',sc.external_league_id,'season_year',sc.season_year,'sync_fixtures',sc.sync_fixtures,'sync_standings',sc.sync_standings,'sync_live',sc.sync_live,'sync_squads',sc.sync_squads,'is_active',sc.is_active)=cfg for share;
     if not found then raise exception 'FOOTBALL_TARGET_CHANGED' using errcode='42501';end if;valid:=true;exit;
    end if;
   end loop;
  end if;
 end if;
 if not valid then raise exception 'FOOTBALL_REQUEST_TARGET_MISMATCH' using errcode='42501';end if;
end $$;
create function public.start_manual_football_request(p_operation_id uuid,p_lease_token uuid,p_url text) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;r public.manual_football_sync_requests;h text;attempts integer;source public.manual_football_sync_requests;
begin
 c:=public.lock_manual_football_sync_command(p_operation_id);
 perform public.assert_manual_football_authority(c,p_lease_token);if c.lease_mode<>'dispatch' then raise exception 'FOOTBALL_RECONCILIATION_READ_ONLY' using errcode='42501';end if;perform public.assert_manual_football_request(c,p_url);
 h:=encode(extensions.digest(convert_to(p_url,'UTF8'),'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(h,31001));
 if exists(select 1 from public.manual_football_sync_requests where url_sha256=h and state in('started','unknown')) then raise exception 'FOOTBALL_REQUEST_OUTCOME_UNKNOWN';end if;
 select * into r from public.manual_football_sync_requests where operation_id=p_operation_id and url_sha256=h and state='accepted' order by attempt desc limit 1;
 if found then perform public.assert_manual_football_authority(c,p_lease_token);return jsonb_build_object('cached',true,'response_status',r.response_status,'response_headers',r.response_headers,'response_body',r.response_body);end if;
 select count(*) into attempts from public.manual_football_sync_requests where operation_id=p_operation_id and url_sha256=h;
 if attempts>=3 or(select count(*) from public.manual_football_sync_requests where operation_id=p_operation_id)>=100 then raise exception 'FOOTBALL_REQUEST_BOUND_EXCEEDED';end if;
 if p_url like 'storage:football-assets/%' then
  select sr.* into source from public.manual_football_sync_requests sr,jsonb_array_elements(c.snapshot->'logos')l where sr.operation_id=p_operation_id and sr.state='accepted' and sr.url=l->>'url' and l->>'path'=substr(p_url,length('storage:football-assets/')+1) order by sr.started_at desc limit 1 for share of sr;
 end if;
 insert into public.manual_football_sync_requests(operation_id,lease_token,lease_proof_id,url,url_sha256,attempt,state,content_sha256,byte_length,content_type,expected_owner,source_request_id)
 values(p_operation_id,p_lease_token,c.lease_proof_id,p_url,h,attempts+1,'started',case when source.request_id is not null then encode(extensions.digest(decode(source.response_body,'base64'),'sha256'),'hex') end,case when source.request_id is not null then octet_length(decode(source.response_body,'base64')) end,case when source.request_id is not null then case when p_url like '%.svg' then 'image/svg+xml' else 'image/png' end end,null,source.request_id) returning * into r;
 -- Target/config and duplicate-barrier waits cannot extend the original proof.
 perform public.assert_manual_football_authority(c,p_lease_token);
 return jsonb_build_object('cached',false,'request_id',r.request_id,'content_sha256',r.content_sha256,'byte_length',r.byte_length,'content_type',r.content_type);
end $$;
create function public.complete_manual_football_request(p_operation_id uuid,p_lease_token uuid,p_request_id uuid,p_status integer,p_headers jsonb,p_body text) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;r public.manual_football_sync_requests;j jsonb;bytes bytea;obj storage.objects;
 original_mode text;original_url text;original_source uuid;
begin
 -- Storage obtains its object tuple before its metadata-only ROW guard. Use
 -- that same order for readback, without treating this immutable path hint as
 -- authority. Recheck the command, request, lease and object after all waits.
 select command.lease_mode,request.url,request.source_request_id into original_mode,original_url,original_source
  from public.manual_football_sync_commands command join public.manual_football_sync_requests request using(operation_id)
  where command.operation_id=p_operation_id and request.request_id=p_request_id;
 if original_mode='reconcile_storage' and original_source is not null then
  select * into obj from storage.objects where bucket_id='football-assets' and name=substr(original_url,length('storage:football-assets/')+1) for share;
 end if;
 c:=public.lock_manual_football_sync_command(p_operation_id);
 select * into r from public.manual_football_sync_requests where operation_id=p_operation_id and request_id=p_request_id for update;
 perform public.assert_manual_football_authority(c,p_lease_token);
 if c.lease_mode='reconcile_storage' and (original_mode is distinct from c.lease_mode or original_url is distinct from r.url or original_source is distinct from r.source_request_id) then raise exception 'FOOTBALL_REQUEST_LEASE_LOST' using errcode='42501';end if;
 if r.request_id is null or(case when c.lease_mode='dispatch' then r.lease_token is distinct from p_lease_token or r.lease_proof_id is distinct from c.lease_proof_id or r.state<>'started' else r.source_request_id is null or r.state<>'unknown' or p_status is distinct from 200 end) then raise exception 'FOOTBALL_REQUEST_LEASE_LOST' using errcode='42501';end if;
 if c.lease_mode='reconcile_storage' then
  if obj.id is null or obj.id is distinct from r.observed_object_id or obj.owner_id is distinct from r.expected_owner or obj.owner is not null or obj.metadata->>'mimetype' is distinct from r.content_type or obj.version='1' or obj.user_metadata->>'manual_football_operation' is distinct from r.operation_id::text
   or obj.user_metadata->>'manual_football_lease' is distinct from r.lease_token::text or obj.user_metadata->>'manual_football_proof' is distinct from r.lease_proof_id::text
   or obj.user_metadata->>'manual_football_request' is distinct from r.request_id::text or obj.user_metadata->>'content_sha256' is distinct from r.content_sha256
   or coalesce(obj.metadata->>'size',obj.metadata->>'contentLength') is distinct from r.byte_length::text then raise exception 'FOOTBALL_STORAGE_BINDING_MISMATCH' using errcode='42501';end if;
  perform public.assert_manual_football_authority(c,p_lease_token);
 end if;
 if p_status is not null then
  if p_status not between 100 and 599 or jsonb_typeof(p_headers) is distinct from 'object' or p_headers-array['content-type','x-ratelimit-requests-limit','x-ratelimit-requests-remaining','x-ratelimit-limit','x-ratelimit-remaining']<>'{}' or octet_length(p_headers::text)>2048 or p_body is null or length(p_body)>5592410 then raise exception 'FOOTBALL_PROVIDER_RESULT_INVALID' using errcode='22023';end if;
  bytes:=decode(p_body,'base64');if octet_length(bytes)>4194304 then raise exception 'FOOTBALL_PROVIDER_RESULT_INVALID' using errcode='22023';end if;
  if r.source_request_id is not null and (r.content_sha256 is distinct from encode(extensions.digest(bytes,'sha256'),'hex') or r.byte_length is distinct from octet_length(bytes) or p_headers->>'content-type' is distinct from r.content_type) then raise exception 'FOOTBALL_STORAGE_BYTES_MISMATCH' using errcode='22023';end if;
  if r.url like 'https://v3.football.api-sports.io/%' then begin j:=convert_from(bytes,'UTF8')::jsonb;exception when others then j:=null;end;end if;
 end if;
 update public.manual_football_sync_requests set state=case when p_status is null then 'unknown' when p_status between 200 and 299 then 'accepted' else 'rejected' end,
 completed_at=clock_timestamp(),response_status=p_status,response_headers=p_headers,response_body=p_body,provider_json=j where request_id=p_request_id;
 perform public.assert_manual_football_authority(c,p_lease_token);return jsonb_build_object('recorded',true);
end $$;
create function public.finish_manual_football_sync(p_operation_id uuid,p_lease_token uuid,p_result jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.manual_football_sync_commands;begin
 c:=public.lock_manual_football_sync_command(p_operation_id);
 perform public.assert_manual_football_authority(c,p_lease_token);
 if jsonb_typeof(p_result) is distinct from 'object' or octet_length(p_result::text)>65536 then raise exception 'FOOTBALL_RESULT_BOUND_EXCEEDED' using errcode='22023';end if;
 update public.manual_football_sync_commands set state=case when exists(select 1 from public.manual_football_sync_requests where operation_id=p_operation_id and state in('started','unknown')) then 'unknown' else 'completed' end,result=p_result where operation_id=p_operation_id returning * into c;
 return public.manual_football_receipt(c);
end $$;
-- Header values exist only on the scoped service SDK. Normal cron keeps its
-- existing independent authority; authenticated callers cannot claim service.
create function public.manual_football_publication_target(c public.manual_football_sync_commands,p_table text,p_row jsonb) returns boolean
language plpgsql security definer set search_path='' as $$
declare cmd text:=(c).arguments->>'command';fixture uuid;external_id text;comp uuid;lineup uuid;
begin
 if p_table in('football_sync_log','football_sync_config') then
  if exists(select 1 from jsonb_array_elements((c).snapshot->'configs')v where v->>'id'=coalesce(p_row->>'sync_config_id',p_row->>'id')) then return true;end if;
  return p_table='football_sync_config' and cmd in('register-league','seed-leagues') and exists(select 1 from public.manual_football_sync_requests r,jsonb_path_query(r.provider_json,'$.response[*].league.id')v where r.operation_id=(c).operation_id and r.state='accepted' and v#>>'{}'=p_row->>'external_league_id');
 end if;
 if p_table='competitions' then
  if cmd='download-logos' then return exists(select 1 from jsonb_array_elements((c).snapshot->'logos')v where v->>'kind'='competitions' and v->>'id'=p_row->>'id') or exists(select 1 from jsonb_array_elements((c).snapshot->'configs')v where v->>'competition_id'=p_row->>'id');end if;
  return cmd in('register-league','seed-leagues') and p_row->>'external_provider'='api-football' and exists(select 1 from public.manual_football_sync_requests r,jsonb_path_query(r.provider_json,'$.response[*].league.id')v where r.operation_id=(c).operation_id and r.state='accepted' and v#>>'{}'=p_row->>'external_competition_id');
 end if;
 if p_table='seasons' then
  return cmd in('register-league','seed-leagues') and exists(select 1 from football.competitions co,public.manual_football_sync_requests r,jsonb_path_query(r.provider_json,'$.response[*].league.id')v where co.id=(p_row->>'competition_id')::uuid and r.operation_id=(c).operation_id and r.state='accepted' and v#>>'{}'=co.external_competition_id);
 end if;
 if p_table='teams' then
  if cmd='download-logos' then return exists(select 1 from jsonb_array_elements((c).snapshot->'logos')v where v->>'kind'='teams' and v->>'id'=p_row->>'id');end if;
  -- The existing fixture pipeline falls back to official home/away team data
  -- when the separate team endpoint has a known failed response.
  return p_row->>'external_provider'='api-football' and exists(select 1 from public.manual_football_sync_requests r,
   lateral(select value from jsonb_path_query(r.provider_json,'$.response[*].team.id') value
    union all select value from jsonb_path_query(r.provider_json,'$.response[*].teams.home.id') value
    union all select value from jsonb_path_query(r.provider_json,'$.response[*].teams.away.id') value)v
   where r.operation_id=(c).operation_id and r.state='accepted' and v.value#>>'{}'=p_row->>'external_team_id');
 end if;
 if p_table='fixtures' then
  return p_row->>'external_provider'='api-football' and exists(select 1 from football.competitions co,football.seasons se,football.teams ht,football.teams at,public.manual_football_sync_requests r,jsonb_path_query(r.provider_json,'$.response[*]')v
   where co.id=(p_row->>'competition_id')::uuid and se.id=(p_row->>'season_id')::uuid and se.competition_id=co.id
    and ht.id=(p_row->>'home_team_id')::uuid and at.id=(p_row->>'away_team_id')::uuid and ht.external_provider='api-football' and at.external_provider='api-football'
    and r.operation_id=(c).operation_id and r.state='accepted' and v->'fixture'->>'id'=p_row->>'external_fixture_id'
    and v->'league'->>'id'=co.external_competition_id and v->'league'->>'season' in(se.year_start::text,se.year_end::text)
    and v->'teams'->'home'->>'id'=ht.external_team_id and v->'teams'->'away'->>'id'=at.external_team_id);
 end if;
 if p_table='standings' then
  return exists(select 1 from jsonb_array_elements((c).snapshot->'configs')v where v->>'competition_id'=p_row->>'competition_id')
   and exists(select 1 from football.competitions co,football.seasons se,football.teams tm,public.manual_football_sync_requests r,jsonb_path_query(r.provider_json,'$.response[*]')v
    where co.id=(p_row->>'competition_id')::uuid and se.id=(p_row->>'season_id')::uuid and se.competition_id=co.id
     and tm.id=(p_row->>'team_id')::uuid and tm.external_provider='api-football' and r.operation_id=(c).operation_id and r.state='accepted'
     and r.url like 'https://v3.football.api-sports.io/standings?%' and v->'league'->>'id'=co.external_competition_id
     and v->'league'->>'season' in(se.year_start::text,se.year_end::text)
     and exists(select 1 from jsonb_path_query(v,'$.league.standings[*][*].team.id')tid where tid#>>'{}'=tm.external_team_id));
 end if;
 if p_table in('fixture_stats','fixture_events','fixture_lineups','fixture_lineup_players') then
  fixture:=(p_row->>'fixture_id')::uuid;
  if p_table='fixture_lineup_players' then select fixture_id into fixture from football.fixture_lineups where id=(p_row->>'fixture_lineup_id')::uuid;end if;
  return cmd in('sync-live','full-sync') and exists(select 1 from jsonb_array_elements((c).snapshot->'live')v where v->>'id'=fixture::text);
 end if;
 if p_table='objects' then return cmd='download-logos' and p_row->>'bucket_id'='football-assets' and exists(select 1 from jsonb_array_elements((c).snapshot->'logos')v where v->>'path'=p_row->>'name');end if;
 if p_table='buckets' then return cmd='download-logos' and p_row->>'id'='football-assets';end if;
 -- predict_lock_due updates predict_pools; prediction_settle_fixture updates
 -- the four active prediction tables and award_prediction_fet publishes the
 -- three physical wallet/reward tables (xp_events writes into fet_events).
 -- The Predict-only retirement already removed
 -- its friend-challenge hook and retained that table in the private retired
 -- schema. Existing financial service/economics guards remain unchanged.
 return cmd in('sync-fixtures','sync-live','sync-history','full-sync','auto-settle') and p_table in('predict_pools','fixture_markets','predictions','prediction_settlements','prediction_slips','fan_memberships','fet_events','fet_wallet_ledger_entries');
end $$;
create function public.guard_manual_football_publication() returns trigger language plpgsql security definer set search_path='' as $$
declare headers jsonb:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb,'{}');op uuid;lease uuid;proof uuid;c public.manual_football_sync_commands;r jsonb;cfg jsonb;attempt public.manual_football_sync_requests;
begin
 -- Storage metadata is available only at ROW level, after its object tuple
 -- lock. Headers must not introduce a competing actor/command-before-object
 -- order; the ROW guard validates the exact stored request and original proof.
 if TG_LEVEL='STATEMENT' and TG_TABLE_SCHEMA='storage' and TG_TABLE_NAME='objects' then return null;end if;
 if TG_LEVEL='ROW' and TG_TABLE_SCHEMA='storage' and TG_TABLE_NAME='objects' and TG_OP<>'DELETE' then
  if new.bucket_id='football-assets' and new.user_metadata?'manual_football_operation' then
  headers:=jsonb_build_object('x-africlub-football-operation',new.user_metadata->>'manual_football_operation','x-africlub-football-lease',new.user_metadata->>'manual_football_lease','x-africlub-football-proof',new.user_metadata->>'manual_football_proof');
  end if;
 end if;
 if not headers?'x-africlub-football-operation' then
  if TG_LEVEL='STATEMENT' then return null;end if;if TG_OP='DELETE' then return old;end if;return new;
 end if;
 if auth.role() is distinct from 'service_role' or (current_setting('role',true) is distinct from 'service_role' and not(TG_TABLE_SCHEMA='storage' and TG_TABLE_NAME='objects' and current_setting('role',true)='supabase_storage_admin')) then raise exception 'FOOTBALL_SERVICE_REQUIRED' using errcode='42501';end if;
 begin op:=(headers->>'x-africlub-football-operation')::uuid;lease:=(headers->>'x-africlub-football-lease')::uuid;proof:=(headers->>'x-africlub-football-proof')::uuid;exception when others then raise exception 'FOOTBALL_CONTEXT_REQUIRED' using errcode='42501';end;
 c:=public.lock_manual_football_sync_command(op);
 if c.lease_proof_id is distinct from proof then raise exception 'FOOTBALL_ORIGINAL_PROOF_REQUIRED' using errcode='42501';end if;
 perform public.assert_manual_football_authority(c,lease);
 if c.lease_mode<>'dispatch' then raise exception 'FOOTBALL_RECONCILIATION_READ_ONLY' using errcode='42501';end if;
 if TG_LEVEL='STATEMENT' then return null;end if;
 r:=case when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if not public.manual_football_publication_target(c,TG_TABLE_NAME,r) or(TG_OP='UPDATE' and not public.manual_football_publication_target(c,TG_TABLE_NAME,to_jsonb(old))) then raise exception 'FOOTBALL_PUBLICATION_TARGET_MISMATCH' using errcode='42501';end if;
 if TG_TABLE_NAME='football_sync_config' and c.arguments->>'command' not in('register-league','seed-leagues') then
  select value into cfg from jsonb_array_elements(c.snapshot->'configs') where value->>'id'=r->>'id';
  if cfg is null or r-array['league_name','sync_interval_minutes','last_synced_at','last_standings_synced_at','last_live_synced_at','last_squads_synced_at','sync_status','metadata','created_at','updated_at'] is distinct from cfg
   or(TG_OP='UPDATE' and to_jsonb(old)-array['league_name','sync_interval_minutes','last_synced_at','last_standings_synced_at','last_live_synced_at','last_squads_synced_at','sync_status','metadata','created_at','updated_at'] is distinct from cfg) then
   raise exception 'FOOTBALL_TARGET_CHANGED' using errcode='42501';end if;
 end if;
 if TG_TABLE_SCHEMA='storage' and TG_TABLE_NAME='objects' then
  select * into attempt from public.manual_football_sync_requests where request_id=(r->'user_metadata'->>'manual_football_request')::uuid and operation_id=op for update;
  if attempt.request_id is null or attempt.state<>'started' or attempt.lease_token is distinct from lease or attempt.lease_proof_id is distinct from proof
   or attempt.url is distinct from 'storage:football-assets/'||(r->>'name') or r->>'owner_id' is distinct from attempt.expected_owner or r->>'owner' is not null or r->'metadata'->>'mimetype' is distinct from attempt.content_type or (attempt.observed_object_id is not null and attempt.observed_object_id::text is distinct from r->>'id') or r->'user_metadata'->>'content_sha256' is distinct from attempt.content_sha256
   or(r->>'version'<>'1' and coalesce(r->'metadata'->>'size',r->'metadata'->>'contentLength') is distinct from attempt.byte_length::text) then raise exception 'FOOTBALL_STORAGE_BINDING_MISMATCH' using errcode='42501';end if;
  if attempt.observed_object_id is null then update public.manual_football_sync_requests set observed_object_id=(r->>'id')::uuid where request_id=attempt.request_id;end if;
 end if;
 -- Recheck after the target-selector waits as well as the row wait.
 perform public.assert_manual_football_authority(c,lease);
 if TG_OP='DELETE' then return old;end if;return new;
end $$;
do $$ declare t text;invalid text[];targets text[]:=array['public.football_sync_config','public.football_sync_log','football.competitions','football.seasons','football.teams','football.fixtures','football.standings','football.fixture_stats','football.fixture_events','football.fixture_lineups','football.fixture_lineup_players','storage.objects','storage.buckets','football.predict_pools','football.fixture_markets','football.predictions','football.prediction_settlements','football.prediction_slips','public.fan_memberships','public.fet_events','public.fet_wallet_ledger_entries'];begin
 select array_agg(publisher.relation_name) into invalid from unnest(targets) as publisher(relation_name) left join pg_class c on c.oid=to_regclass(publisher.relation_name) where coalesce(c.relkind not in('r','p'),true);
 if invalid is not null then raise exception 'FOOTBALL_PUBLICATION_RELATION_MISMATCH: %',invalid;end if;
 -- Guard the real backing rows. A compatibility view only admits statement
 -- guards; its original INSTEAD OF writer must still reach guarded fet_events.
 if (select relkind from pg_class where oid='public.xp_events'::regclass) is distinct from 'v'
  or not exists(select 1 from pg_trigger where tgrelid='public.xp_events'::regclass and tgname='trg_xp_events_compat_write'
   and tgfoid='public.xp_events_compat_write()'::regprocedure and (tgtype::integer&64)=64 and tgenabled<>'D')
  or not exists(select 1 from pg_rewrite r join pg_depend d on d.classid='pg_rewrite'::regclass and d.objid=r.oid
   where r.ev_class='public.xp_events'::regclass and d.refclassid='pg_class'::regclass and d.refobjid='public.fet_events'::regclass) then
  raise exception 'FOOTBALL_REWARD_WRITER_CHANGED';end if;
 foreach t in array targets loop
  execute format('create trigger manual_football_statement_guard before insert or update or delete on %s for each statement execute function public.guard_manual_football_publication()',t);
  execute format('create trigger manual_football_row_guard before insert or update or delete on %s for each row execute function public.guard_manual_football_publication()',t);
 end loop;
end $$;
create trigger manual_football_statement_guard before insert or update or delete on public.xp_events for each statement execute function public.guard_manual_football_publication();
create trigger manual_football_storage_after after insert or update on storage.objects for each row execute function public.guard_manual_football_publication();
revoke all on function public.manual_football_json_hash(jsonb),public.manual_football_arguments(jsonb),public.manual_football_snapshot(),public.manual_football_storage_recovery(public.manual_football_sync_commands),public.guard_manual_football_immutable(),
 public.manual_football_receipt(public.manual_football_sync_commands),public.lock_manual_football_sync_command(uuid),public.assert_manual_football_authority(public.manual_football_sync_commands,uuid),public.manual_football_url_decode(text),public.assert_manual_football_request(public.manual_football_sync_commands,text),
 public.manual_football_publication_target(public.manual_football_sync_commands,text,jsonb),public.guard_manual_football_publication(),
 public.admit_manual_football_sync(uuid,jsonb),public.recover_manual_football_sync(uuid),public.claim_manual_football_sync(uuid,uuid,uuid),public.start_manual_football_request(uuid,uuid,text),
 public.complete_manual_football_request(uuid,uuid,uuid,integer,jsonb,text),public.assert_manual_football_sync(uuid,uuid),public.finish_manual_football_sync(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.admit_manual_football_sync(uuid,jsonb),public.recover_manual_football_sync(uuid) to authenticated;
grant execute on function public.claim_manual_football_sync(uuid,uuid,uuid),public.start_manual_football_request(uuid,uuid,text),public.complete_manual_football_request(uuid,uuid,uuid,integer,jsonb,text),public.assert_manual_football_sync(uuid,uuid),public.finish_manual_football_sync(uuid,uuid,jsonb) to service_role;
commit;
