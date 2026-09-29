begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(29);

-- Nonempty profiles are legitimate for other clubs (Costa do Sol is sourced by
-- 20260923223000_add_costa_do_sol_club.sql). Detect the Rayon-specific identity
-- and attribution instead of requiring every other tenant profile to be empty.
create function pg_temp.rayon_identity_leak_count() returns integer
language sql stable as $$
  select count(*)::integer from public.african_football_clubs
  where id <> 24 and (
    club_profile->>'full_name' = 'Rayon Sports Football Club'
    or club_profile->>'source_repository' = 'Gikundiro'
    or club_profile->'source_records' ? 'club-value-gikundiro'
    or club_profile->'source_urls' ?| array[
      'https://x.com/rayon_sports', 'https://www.youtube.com/@rayon_sports'
    ]
    or club_profile->>'crest_asset_key' = 'team.crest.rpl-official.rayon-sports'
  );
$$;

select is((select club_profile->>'origin' from public.african_football_clubs where id=24), 'Nyanza, Southern Province, Rwanda', 'identity uses the sourced Nyanza origin');
select is((select club_profile->>'current_base' from public.african_football_clubs where id=24), 'Kigali, Rwanda', 'current base matches approved source');
select is((select club_profile->>'colours' from public.african_football_clubs where id=24), 'Blue and white', 'colours preserve club identity');
select ok((select official_logo_url ~ '^https://.*\.png$' from public.african_football_clubs where id=24), 'crest is an actual image URL');
select is(pg_temp.rayon_identity_leak_count(), 0, 'Rayon-specific identity and attribution are not assigned to other tenants');
select is((select count(*)::integer from public.ai_content where club_id<>24 and source_record like 'gikundiro:%'), 0, 'Rayon editorial source records remain scoped to Rayon');

-- Prove the detector rejects whole-profile and partial-attribution leaks while
-- allowing Costa do Sol's valid profile. All mutations roll back in this test.
savepoint foreign_identity_probe;
update public.african_football_clubs
set club_profile = (select club_profile from public.african_football_clubs where id=24)
where id=1001;
select is(pg_temp.rayon_identity_leak_count(), 1, 'a copied Rayon profile on Costa do Sol is detected');
rollback to savepoint foreign_identity_probe;
update public.african_football_clubs
set club_profile = club_profile || jsonb_build_object('source_repository', 'Gikundiro')
where id=1001;
select is(pg_temp.rayon_identity_leak_count(), 1, 'a partial Rayon attribution leak on Costa do Sol is detected');
rollback to savepoint foreign_identity_probe;
release savepoint foreign_identity_probe;
select is((select count(*)::integer from public.ai_content where club_id=24 and content_type='club_history' and is_active and title in ('The beloved identity','Matchday at scale','One supporter account')), 0, 'duplicated software copy is retired from history');
select is((select count(*)::integer from public.ai_content where club_id=24 and content_type='club_history' and is_active and status='approved' and source_record like 'gikundiro:%'), 3, 'three sourced identity and history records');
select is((select count(*)::integer from public.ai_content where source_record like 'gikundiro:%' and (source_url is null or source_label is null)), 0, 'every imported record retains attribution');
select is((select club_profile->>'full_name' from public.african_football_clubs where id=1001), 'Clube de Desportos da Costa do Sol', 'Costa do Sol retains its own sourced full name');
select is((select club_profile->>'identity_note' from public.african_football_clubs where id=1001), 'Os Canarinhos', 'Costa do Sol retains its own supporter identity');
select ok((select club_profile->'source_urls' ? 'https://cdcostadosol.s1.emjogo.pt/pt/' from public.african_football_clubs where id=1001), 'Costa do Sol retains its own official source attribution');

update public.african_football_clubs
set official_contact = 'qa-private-contact-' || id,
    market_research_note = 'qa-private-research-' || id
where id in (6,24,26,44,1001);
insert into public.ai_content
  (club_id, content_type, title, body, status, is_active, distribution, source_record)
values (1001, 'club_history', 'QA Costa do Sol public history', 'Synthetic Costa do Sol history fixture',
        'approved', true, 'both', 'qa:costa-do-sol-public-history');
set local role anon;
select is((public.club_public_overview(24)->'club_profile'->>'full_name'), 'Rayon Sports Football Club', 'public can read approved club identity');
select is(jsonb_array_length(public.club_public_history(24)), 3, 'public history exposes approved records');
select ok(not (public.club_public_overview(24) ? 'official_contact'), 'private registry fields are outside the public projection');
select is(public.club_public_overview(-1), null::jsonb, 'unknown club does not fall through to Rayon identity');
-- Independent expected identities prevent wrong-tenant or fallback projections
-- from passing simply because the requested record exists.
select is(
  jsonb_build_object(
    'id', public.club_public_overview(expected.id)->'id',
    'name', public.club_public_overview(expected.id)->>'club_name',
    'slug', public.club_public_overview(expected.id)->>'club_slug',
    'country', public.club_public_overview(expected.id)->>'country_name'
  ),
  jsonb_build_object('id', expected.id, 'name', expected.name,
                     'slug', expected.slug, 'country', expected.country),
  expected.name || ' public projection preserves its own tenant identity'
)
from (values
  (6::bigint, 'AS Vita Club', 'as_vita_cd', 'DR Congo'),
  (24::bigint, 'Rayon Sports FC', 'rayon_sports_rw', 'Rwanda'),
  (26::bigint, 'Nkana FC', 'nkana_zm', 'Zambia'),
  (44::bigint, 'Vital''O FC', 'vitalo_bi', 'Burundi'),
  (1001::bigint, 'CD Costa do Sol', 'costa_do_sol_mz', 'Mozambique')
) expected(id, name, slug, country);
select is((
  select count(*)::integer from (values (6::bigint),(26),(44),(1001)) clubs(id)
  where exists (
    select 1 from jsonb_array_elements(public.club_public_history(clubs.id)) item
    where item->>'source_url' in ('https://x.com/rayon_sports', 'https://www.youtube.com/@rayon_sports')
  )
), 0, 'non-Rayon public histories do not fall through to Rayon attribution');
select is((
  select count(*)::integer from (values (6::bigint),(24),(26),(44),(1001)) clubs(id)
  where public.club_public_overview(clubs.id) ?| array[
    'official_contact', 'market_research_note', 'country_population',
    'momo_sender_name', 'momo_ussd_template', 'is_onboarded', 'onboarding_priority', 'feature_flags'
  ]
), 0, 'all five public projections omit private operational and research fields');
select is((
  select count(*)::integer from (values (6::bigint),(24),(26),(44),(1001)) clubs(id)
  where public.club_public_overview(clubs.id)::text like '%qa-private-%'
), 0, 'private sentinels cannot leak under renamed public fields');
select is(public.club_public_history(1001)->0->>'title', 'QA Costa do Sol public history', 'Costa do Sol public history reads its own approved record');
reset role;
update public.african_football_clubs set is_active=false where id=1001;
set local role anon;
select is(public.club_public_overview(1001), null::jsonb, 'inactive Costa do Sol identity is unavailable publicly');
select is(public.club_public_history(1001), '[]'::jsonb, 'inactive Costa do Sol approved history is unavailable publicly');
reset role;
select * from finish();
rollback;
