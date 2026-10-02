-- Synthetic existing scheduled notifications BEFORE SQL29. The existing trusted
-- service insert path is exercised; no provider or cron call occurs. Club24 is
-- from the canonical five-club catalog; distinct999689 IDs never add seed clubs.
begin;
set local search_path=public,extensions;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claim.sub','',true);

insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 values('99968900-0000-4000-8000-000000000001','authenticated','authenticated',now(),false);
insert into public.users(id,phone,full_name,public_user_id)
 values('99968900-0000-4000-8000-000000000001','+250799968901','Synthetic scheduled notification creator','968901');
insert into public.profiles(id,club_id) values('99968900-0000-4000-8000-000000000001',24);
insert into public.admin_role_assignments(user_id,role,club_id)
 values('99968900-0000-4000-8000-000000000001','super_admin',null);

-- Actual pre-command trusted service capability, unchanged from the old Edge
-- creation path. The null creator represents an already scrubbed historical row.
set local role service_role;
insert into public.notifications(id,club_id,created_by,title,body,image_url,audience_type,
 audience_tier,audience_group_id,audience_group_name,delivery_mode,scheduled_at,status,created_at,
 requested_recipient_count,successful_user_count,failed_user_count,sent_count,failed_count,cleaned_tokens,
 last_error,delivery_summary,updated_at)
 values
 ('99968900-0000-4000-8000-000000000101',24,'99968900-0000-4000-8000-000000000001',
  'Legacy scheduled ordinary','Preserve this original scheduled message.',null,'all_fans',null,null,null,
  'schedule','2026-01-01T12:00:00.123Z','scheduled','2025-12-01T08:00:00Z',
  0,0,0,0,0,0,null,'{}','2025-12-01T08:00:00Z'),
 ('99968900-0000-4000-8000-000000000102',24,null,
  'Legacy scheduled scrubbed','Preserve a job whose former creator is no longer identified.',
  'https://example.test/legacy-image.png','all_fans',null,null,null,
  'schedule','2026-01-02T12:00:00.456Z','scheduled','2025-12-02T08:00:00Z',
  0,0,0,0,0,0,null,'{}','2025-12-02T08:00:00Z');
reset role;
commit;

-- Root harness snapshots and compares ALL original columns by the exact IDs:
-- select coalesce(jsonb_agg(to_jsonb(n) order by n.id),'[]'::jsonb)::text
-- from public.notifications n where n.id in
-- ('99968900-0000-4000-8000-000000000101','99968900-0000-4000-8000-000000000102');
-- After29, require exactly2 command rows bound to the same notification/operation
-- IDs, authority_kind='legacy_scheduled', state='scheduled', current/lease proof
-- NULL, and zero manufactured admin_notification_proofs/device attempts. Later
-- service claim may use NULL proof and must retain independent cron authority.
