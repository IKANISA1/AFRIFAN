-- Local public catalog only. Identity, IDs, countries and currencies come from
-- the twenty app flavor files and their matching ClubConfig implementations.
-- Non-Rayon seed slugs are local identifiers derived from app folder and country.
-- No Auth users, operator grants, provider credentials or onboarding approvals.
begin;

-- Country parents required by club identity foreign keys. Names/currencies are
-- the local app configuration values; dialing codes were checked against ITU
-- https://www.itu.int/oth/t0202 on 2026-09-15 (page updated 2026-09-09).
-- Missing country records stay inactive with no provider or USSD routing values.
-- Existing country activation and routing are preserved.
insert into public.countries
  (id, name, dialing_code, currency, phone_placeholder, is_active)
values
  ('BI', 'Burundi', '+257', 'BIF', '', false),
  ('BJ', 'Benin', '+229', 'XOF', '', false),
  ('CD', 'DR Congo', '+243', 'CDF', '', false),
  ('CG', 'Congo Republic', '+242', 'XAF', '', false),
  ('CI', 'Ivory Coast', '+225', 'XOF', '', false),
  ('CM', 'Cameroon', '+237', 'XAF', '', false),
  ('GA', 'Gabon', '+241', 'XAF', '', false),
  ('GH', 'Ghana', '+233', 'GHS', '', false),
  ('MW', 'Malawi', '+265', 'MWK', '', false),
  ('RW', 'Rwanda', '+250', 'RWF', '', false),
  ('TG', 'Togo', '+228', 'XOF', '', false),
  ('TZ', 'Tanzania', '+255', 'TZS', '', false),
  ('ZM', 'Zambia', '+260', 'ZMW', '', false),
  ('ZW', 'Zimbabwe', '+263', 'USD', '', false)
on conflict (id) do nothing;

insert into public.african_football_clubs
  (id,club_name,country_name,club_slug,currency_code,currency_symbol,league)
overriding system value values
  (49,'AC Léopards','Congo Republic','ac_leopards_cg','XAF','FCFA',null),
  (21,'Africa Sports National','Ivory Coast','africa_sports_ci','XOF','CFA',null),
  (69,'AS Mangasport','Gabon','as_mangasport_ga','XAF','FCFA',null),
  (6,'AS Vita Club','DR Congo','as_vita_cd','CDF','FC',null),
  (9,'Asante Kotoko SC','Ghana','asante_kotoko_gh','GHS','GH₵',null),
  (14,'ASEC Mimosas','Ivory Coast','asec_mimosas_ci','XOF','CFA',null),
  (45,'ASKO de Kara','Togo','asko_kara_tg','XOF','CFA',null),
  (31,'Canon Yaoundé','Cameroon','canon_yaounde_cm','XAF','FCFA',null),
  (19,'Dynamos FC','Zimbabwe','dynamos_zw','USD','$',null),
  (58,'Maranatha FC','Togo','maranatha_tg','XOF','CFA',null),
  (73,'Mogas 90 FC','Benin','mogas_90_bj','XOF','CFA',null),
  (26,'Nkana FC','Zambia','nkana_zm','ZMW','ZK',null),
  (17,'Nyasa Big Bullets FC','Malawi','nyasa_bullets_mw','MWK','MK',null),
  (24,'Rayon Sports FC','Rwanda','rayon_sports_rw','RWF','RWF','Rwanda Premier League'),
  (3,'Simba SC','Tanzania','simba_tz','TZS','TSh',null),
  (4,'TP Mazembe','DR Congo','tp_mazembe_cd','CDF','FC',null),
  (33,'Union Douala','Cameroon','union_douala_cm','XAF','FCFA',null),
  (44,'Vital''O FC','Burundi','vitalo_bi','BIF','FBu',null),
  (1,'Young Africans (Yanga)','Tanzania','yanga_tz','TZS','TSh',null),
  (35,'ZESCO United FC','Zambia','zesco_united_zm','ZMW','ZK',null)
on conflict (id) do nothing;

-- Complete the local UI identity from the existing ClubConfig implementations.
-- appName is the local display identity; no new public club nickname is asserted.
-- Preserve already configured values when the local catalog is reseeded.
update public.african_football_clubs as club
set nickname_brand_identity = coalesce(club.nickname_brand_identity, identity.nickname),
    country_iso_code = coalesce(club.country_iso_code, identity.country_code),
    primary_color_hex = coalesce(club.primary_color_hex, identity.primary_color),
    secondary_color_hex = coalesce(club.secondary_color_hex, identity.secondary_color),
    accent_color_hex = coalesce(club.accent_color_hex, identity.accent_color)
from (values
  (49, 'AC Léopards', 'CG', '#006B3F', '#D1D5DB', '#000000'),
  (21, 'Africa Sports', 'CI', '#006B3F', '#CC0000', '#D1D5DB'),
  (69, 'AS Mangasport', 'GA', '#FFD700', '#006B3F', '#000000'),
  (6, 'AS Vita Club', 'CD', '#006400', '#000000', '#FFD700'),
  (9, 'Asante Kotoko', 'GH', '#CC0000', '#D1D5DB', '#FFD700'),
  (14, 'ASEC Mimosas', 'CI', '#FFD700', '#000000', '#FF8C00'),
  (45, 'ASKO Kara', 'TG', '#FFD700', '#006B3F', '#000000'),
  (31, 'Canon Yaoundé', 'CM', '#006B3F', '#CC0000', '#FFD700'),
  (19, 'Dynamos FC', 'ZW', '#0000CC', '#D1D5DB', '#FFD700'),
  (58, 'Maranatha FC', 'TG', '#CC0000', '#D1D5DB', '#FFD700'),
  (73, 'Mogas 90', 'BJ', '#006B3F', '#D1D5DB', '#CC0000'),
  (26, 'Nkana FC', 'ZM', '#CC0000', '#D1D5DB', '#000000'),
  (17, 'Nyasa Bullets', 'MW', '#CC0000', '#D1D5DB', '#000000'),
  (24, 'Gikundiro', 'RW', '#0038A8', '#001742', '#D9B24C'),
  (3, 'Simba SC', 'TZ', '#CC0000', '#D1D5DB', '#FFD700'),
  (4, 'TP Mazembe', 'CD', '#000000', '#D1D5DB', '#C0C0C0'),
  (33, 'Union Douala', 'CM', '#006B3F', '#D1D5DB', '#000000'),
  (44, 'Vital''O', 'BI', '#7B2D8E', '#D1D5DB', '#FFD700'),
  (1, 'Yanga SC', 'TZ', '#006B3F', '#FFD700', '#D1D5DB'),
  (35, 'ZESCO United', 'ZM', '#006B3F', '#FF8C00', '#D1D5DB')
) as identity(id, nickname, country_code, primary_color, secondary_color, accent_color)
where club.id = identity.id
  and (club.nickname_brand_identity is null or club.country_iso_code is null
    or club.primary_color_hex is null or club.secondary_color_hex is null
    or club.accent_color_hex is null);

-- The identity migration precedes seeding on clean resets. Apply its exact
-- previously sourced public-data statements after the local club row exists.
-- Data authority: migrations/20260906090100_gikundiro_club_identity.sql.
update public.african_football_clubs
set official_logo_url = 'https://loxcwbfukbqziuxgkfcm.supabase.co/storage/v1/object/public/gikundiro-media/fc49b605-6eda-408d-afc6-46e11bc17710/library/teams/rayon-sports.png',
    nickname_brand_identity = 'Gikundiro',
    primary_brand_colors = 'Blue, White',
    club_profile = jsonb_build_object(
      'full_name', 'Rayon Sports Football Club',
      'origin', 'Nyanza, Southern Province, Rwanda',
      'current_base', 'Kigali, Rwanda',
      'colours', 'Blue and white',
      'identity_note', 'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.',
      'source_locale', 'en',
      'source_repository', 'Gikundiro',
      'source_records', jsonb_build_array('club-identity-full-name', 'club-identity-origin', 'club-value-gikundiro'),
      'source_urls', jsonb_build_array('https://x.com/rayon_sports', 'https://www.youtube.com/@rayon_sports'),
      'crest_source_url', 'https://rwandapremierleague.rw/',
      'crest_asset_key', 'team.crest.rpl-official.rayon-sports',
      'crest_sha256', '0ef8c691c97a76d7dc36ef7a3fbe02367b23a73f9478c742c5b0cfead699b963',
      'crest_usage_rights', 'official-competition-source-review-before-commercial-reuse',
      'source_checked_at', '2026-09-06'
    ), updated_at = now()
where id = 24 and club_slug = 'rayon_sports_rw';

-- Retain the superseded records for traceability, removing them from public reads.
-- These exact duplicate headings described software features, not club history.
update public.ai_content set is_active = false, updated_at = now()
where club_id = 24 and content_type = 'club_history' and source_record is null
  and title in ('The beloved identity', 'Matchday at scale', 'One supporter account');

insert into public.ai_content
  (club_id, content_type, title, subtitle, body, sort_order, status, is_active,
   distribution, source_record, source_label, source_url, rationale)
select 24, 'club_history'::public.ai_content_type, item.title, item.subtitle,
  item.body, item.sort_order, 'approved'::public.ai_content_status, true, 'both',
  item.source_record, item.source_label, item.source_url,
  'Adapted from the published approved Gikundiro Club ledger, independently read back on 2026-09-06. Unsupported dates and honours are omitted.'
from (values
  ('Roots in Nyanza', 'Nyanza, Southern Province', 'Rayon Sports FC traces its roots to Nyanza in Rwanda''s Southern Province.', 10, 'gikundiro:club-history-roots-nyanza', 'Rayon Sports TV', 'https://www.youtube.com/@rayon_sports'),
  ('Based in Kigali', 'Kigali, Rwanda', 'The club is now based in Kigali while retaining its historic connection to Nyanza.', 20, 'gikundiro:club-history-base-kigali', 'Rayon Sports TV', 'https://www.youtube.com/@rayon_sports'),
  ('Gikundiro', 'Supporter identity', 'Gikundiro is the supporter identity carried by Rayon Sports FC across its official social presence.', 30, 'gikundiro:club-value-gikundiro', 'Rayon Sports FC', 'https://x.com/rayon_sports')
) item(title, subtitle, body, sort_order, source_record, source_label, source_url)
where exists (select 1 from public.african_football_clubs where id = 24 and club_slug = 'rayon_sports_rw')
on conflict (club_id, content_type, source_record) where source_record is not null
  do update set title=excluded.title, subtitle=excluded.subtitle, body=excluded.body,
    sort_order=excluded.sort_order, status=excluded.status, is_active=excluded.is_active,
    source_label=excluded.source_label, source_url=excluded.source_url,
    rationale=excluded.rationale, updated_at=now();

select setval(pg_get_serial_sequence('public.african_football_clubs','id'),
  (select max(id) from public.african_football_clubs), true);
commit;
