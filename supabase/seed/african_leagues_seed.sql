-- Auto-generated: DR Congo Linafoot, ZSL, Rwanda Premier League

-- ══════════════════════════════════════════════════════════════════
-- DR Congo Linafoot Ligue 1
-- ══════════════════════════════════════════════════════════════════

INSERT INTO football.competitions (id, slug, name, short_name, competition_kind, region, country_code, country_name, organizer, gender, is_active)
VALUES ('ec0e015c-f2bd-41d0-8e53-69176b661a30', 'dr-congo-linafoot-2026', 'DR Congo Linafoot Ligue 1', 'Linafoot', 'league', 'africa', 'CD', 'DR Congo', 'FECOFA', 'male', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO football.seasons (id, competition_id, slug, label, year_start, year_end, starts_on, ends_on, status, is_active)
VALUES ('f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'linafoot-2025-26', '2025-26', 2025, 2026, '2026-04-14', '2026-05-31', 'active', true)
ON CONFLICT (slug) DO NOTHING;

-- Teams (17)
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('89ae3282-2b9b-4d03-89dc-d49a8056e1cb', 'malole', 'Malole', 'MAL', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('3bb819cc-0fc0-440f-8143-37e238066abb', 'blessing-fc', 'Blessing FC', 'BLE', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'fc-les-aigles-du-congo', 'FC Les Aigles du Congo', 'FC ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', 'celeste-fc', 'Céleste FC', 'CÉL', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('0047fc5a-e7c4-488f-8b0a-d77a3ea7a66b', 'as-new-soger', 'AS New Soger', 'AS ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('954b4931-459b-46a6-812c-f34cd2b61a8b', 'tp-mazembe', 'TP Mazembe', 'TP ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('67ca285b-c737-46d2-8443-e2968a10eef9', 'cs-don-bosco', 'CS Don Bosco', 'CS ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('c7364492-3738-4ed6-8037-0ce2994929dd', 'fc-saint-eloi-lupopo', 'FC Saint-Éloi Lupopo', 'FC ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('c9724ee8-163b-4ef2-80fb-4822818d7908', 'as-vclub', 'AS V.Club', 'AS ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('a61e5411-af92-4ab7-84bb-26e158707d57', 'dcmp', 'DCMP', 'DCM', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'maniema-union', 'Maniema Union', 'MAN', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('1408bb64-3cac-4851-8c28-cbd7dcc9f315', 'lubumbashi-sport', 'Lubumbashi Sport', 'LUB', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('d8c6a104-6acb-47a8-85c1-a52f11c3debc', 'as-dauphin-noir', 'AS Dauphin Noir', 'AS ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('d19deb65-7af7-4ea8-87ec-c14a3b9f43f1', 'as-simba', 'AS Simba', 'AS ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('29cbc3dd-d867-416b-8860-151aeda64f56', 'js-groupe-bazano', 'JS Groupe Bazano', 'JS ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('22cce71c-93fc-4914-8f8e-8afc8f57cd66', 'us-panda-b52', 'US Panda B52', 'US ', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('24fa9856-0fc5-4cd8-8a45-db894274237d', 'etoile-de-kivu', 'Etoile de Kivu', 'ETO', 'club', 'CD', 'DR Congo', true)
ON CONFLICT (slug) DO NOTHING;

-- Fixtures (49)
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('43e73192-2d32-42dd-8b3f-10a1bce352fe', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 1, '2026-04-14 13:00:00+00', 'DR Congo', 'DR Congo', '89ae3282-2b9b-4d03-89dc-d49a8056e1cb', '3bb819cc-0fc0-440f-8143-37e238066abb', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('a40cfb23-8e77-4a04-8842-1dd13541891e', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 2, '2026-04-14 13:00:00+00', 'DR Congo', 'DR Congo', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('8774a6bf-9476-4f28-8fea-252e81974d12', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 3, '2026-04-15 13:00:00+00', 'DR Congo', 'DR Congo', '0047fc5a-e7c4-488f-8b0a-d77a3ea7a66b', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('4288313d-c4f8-40e7-8738-38dd76235818', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 4, '2026-04-15 13:00:00+00', 'DR Congo', 'DR Congo', '67ca285b-c737-46d2-8443-e2968a10eef9', 'c7364492-3738-4ed6-8037-0ce2994929dd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('a3a058fb-970f-4bb7-8198-0258c3653584', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 5, '2026-04-18 13:00:00+00', 'DR Congo', 'DR Congo', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'a61e5411-af92-4ab7-84bb-26e158707d57', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('2dafeef7-89da-4aa9-8b01-0607a19e97b6', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 6, '2026-04-18 13:00:00+00', 'DR Congo', 'DR Congo', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6eded7ef-2616-48c8-8691-64a164527411', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 7, '2026-04-18 13:00:00+00', 'DR Congo', 'DR Congo', '1408bb64-3cac-4851-8c28-cbd7dcc9f315', '67ca285b-c737-46d2-8443-e2968a10eef9', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('370def04-e46d-48c4-8438-f426603910be', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 8, '2026-04-19 13:00:00+00', 'DR Congo', 'DR Congo', 'c7364492-3738-4ed6-8037-0ce2994929dd', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('8ec903ac-cdb9-4bc5-8403-a82c0793b394', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 9, '2026-04-19 13:00:00+00', 'DR Congo', 'DR Congo', 'd8c6a104-6acb-47a8-85c1-a52f11c3debc', 'a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b584a3b6-b699-4325-8bc0-606b4f64b254', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 10, '2026-04-19 13:00:00+00', 'DR Congo', 'DR Congo', 'd19deb65-7af7-4ea8-87ec-c14a3b9f43f1', '29cbc3dd-d867-416b-8860-151aeda64f56', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('dec0c677-f1e4-4487-8262-883095b64346', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 11, '2026-04-22 13:00:00+00', 'DR Congo', 'DR Congo', '954b4931-459b-46a6-812c-f34cd2b61a8b', '1408bb64-3cac-4851-8c28-cbd7dcc9f315', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e35fd01f-f77f-4a5d-811e-dc54f379551f', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 12, '2026-04-22 13:00:00+00', 'DR Congo', 'DR Congo', 'a61e5411-af92-4ab7-84bb-26e158707d57', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('23ef325f-0e76-4ac8-89ed-f69ea524839a', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 13, '2026-04-22 13:00:00+00', 'DR Congo', 'DR Congo', '3bb819cc-0fc0-440f-8143-37e238066abb', 'd19deb65-7af7-4ea8-87ec-c14a3b9f43f1', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5d67aec6-667b-46f6-86ee-718edb2b5bbf', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 14, '2026-04-25 13:00:00+00', 'DR Congo', 'DR Congo', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('00083ba8-cd9c-4986-8391-d0e157117e50', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 15, '2026-04-25 13:00:00+00', 'DR Congo', 'DR Congo', '67ca285b-c737-46d2-8443-e2968a10eef9', '0047fc5a-e7c4-488f-8b0a-d77a3ea7a66b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('f9bfe4e1-ab42-4e88-8f32-4dffa79f1911', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 16, '2026-04-25 13:00:00+00', 'DR Congo', 'DR Congo', 'c7364492-3738-4ed6-8037-0ce2994929dd', '89ae3282-2b9b-4d03-89dc-d49a8056e1cb', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('2612fe90-0d8d-4412-86f1-288a188194f2', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 17, '2026-04-26 13:00:00+00', 'DR Congo', 'DR Congo', 'a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', 'a61e5411-af92-4ab7-84bb-26e158707d57', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('74eca3e8-7dfe-47b1-8683-1e1caecee287', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 18, '2026-04-26 13:00:00+00', 'DR Congo', 'DR Congo', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'd8c6a104-6acb-47a8-85c1-a52f11c3debc', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('4eada537-a23f-41f7-885b-d1673fd1cc1c', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 19, '2026-04-26 13:00:00+00', 'DR Congo', 'DR Congo', '29cbc3dd-d867-416b-8860-151aeda64f56', '22cce71c-93fc-4914-8f8e-8afc8f57cd66', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('69a501f4-d385-4d4d-804f-3086e769aaac', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 20, '2026-04-29 13:00:00+00', 'DR Congo', 'DR Congo', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('66155c1d-4786-4c29-84b5-5c3524c70bb4', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 21, '2026-04-29 13:00:00+00', 'DR Congo', 'DR Congo', '954b4931-459b-46a6-812c-f34cd2b61a8b', '67ca285b-c737-46d2-8443-e2968a10eef9', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('7a82b4f1-a93a-44d5-848c-e76acf6119e8', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 22, '2026-04-29 13:00:00+00', 'DR Congo', 'DR Congo', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'a61e5411-af92-4ab7-84bb-26e158707d57', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5fc147da-00fb-4c7d-825e-6717c675b209', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 23, '2026-05-02 13:00:00+00', 'DR Congo', 'DR Congo', 'c7364492-3738-4ed6-8037-0ce2994929dd', '1408bb64-3cac-4851-8c28-cbd7dcc9f315', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('1c8185bb-4396-4fc7-802b-d823ab6ac37c', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 24, '2026-05-02 13:00:00+00', 'DR Congo', 'DR Congo', 'd8c6a104-6acb-47a8-85c1-a52f11c3debc', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('07c7df54-854d-49ec-8d2c-6a0220dd67ab', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 25, '2026-05-02 13:00:00+00', 'DR Congo', 'DR Congo', '3bb819cc-0fc0-440f-8143-37e238066abb', '29cbc3dd-d867-416b-8860-151aeda64f56', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5c4657d1-5352-4e49-8db1-6e5f8d367cd3', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 26, '2026-05-03 13:00:00+00', 'DR Congo', 'DR Congo', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('3d27a461-1d1a-42b7-8ea2-d87410170664', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 27, '2026-05-03 13:00:00+00', 'DR Congo', 'DR Congo', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'd8c6a104-6acb-47a8-85c1-a52f11c3debc', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('a032ca7f-1fb9-44e1-8265-a11af37cbfe9', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 28, '2026-05-03 13:00:00+00', 'DR Congo', 'DR Congo', 'a61e5411-af92-4ab7-84bb-26e158707d57', '24fa9856-0fc5-4cd8-8a45-db894274237d', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('f42bc6af-a302-4d87-86f2-7c6cd6c6d773', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 29, '2026-05-06 13:00:00+00', 'DR Congo', 'DR Congo', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'c7364492-3738-4ed6-8037-0ce2994929dd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('2ec856a0-e521-437c-8946-01dc724f9826', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 30, '2026-05-06 13:00:00+00', 'DR Congo', 'DR Congo', '67ca285b-c737-46d2-8443-e2968a10eef9', '89ae3282-2b9b-4d03-89dc-d49a8056e1cb', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('1c6d9f64-16d4-4d2e-85a7-070917a79960', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 31, '2026-05-06 13:00:00+00', 'DR Congo', 'DR Congo', 'd19deb65-7af7-4ea8-87ec-c14a3b9f43f1', '22cce71c-93fc-4914-8f8e-8afc8f57cd66', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('80ff8429-d4a8-4e54-815d-7781bd249f2e', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 32, '2026-05-09 13:00:00+00', 'DR Congo', 'DR Congo', 'a61e5411-af92-4ab7-84bb-26e158707d57', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9dc99a62-bf76-44ec-8bf1-4af5b4fc576c', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 33, '2026-05-09 13:00:00+00', 'DR Congo', 'DR Congo', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('78a33078-8b11-498f-8940-a5cd183838f5', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 34, '2026-05-09 13:00:00+00', 'DR Congo', 'DR Congo', 'a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', '24fa9856-0fc5-4cd8-8a45-db894274237d', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('4bc6c5ec-e541-4a10-8a17-d88d2693768f', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 35, '2026-05-10 13:00:00+00', 'DR Congo', 'DR Congo', '1408bb64-3cac-4851-8c28-cbd7dcc9f315', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b4a153d1-74cc-47a2-8b77-24570e257fc5', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 36, '2026-05-10 13:00:00+00', 'DR Congo', 'DR Congo', '0047fc5a-e7c4-488f-8b0a-d77a3ea7a66b', 'c7364492-3738-4ed6-8037-0ce2994929dd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('09541352-3395-45ff-8681-14b4b1789c4c', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 37, '2026-05-16 13:00:00+00', 'DR Congo', 'DR Congo', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('99fdfc0b-fd42-4220-8912-0d260c04d958', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 38, '2026-05-16 13:00:00+00', 'DR Congo', 'DR Congo', 'c7364492-3738-4ed6-8037-0ce2994929dd', 'a61e5411-af92-4ab7-84bb-26e158707d57', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('69dd1505-6af2-47bb-8815-d4426625e91f', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 39, '2026-05-16 13:00:00+00', 'DR Congo', 'DR Congo', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', '67ca285b-c737-46d2-8443-e2968a10eef9', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('37e36eea-5548-410d-8bac-7fb7a65deec5', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 40, '2026-05-17 13:00:00+00', 'DR Congo', 'DR Congo', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', '1408bb64-3cac-4851-8c28-cbd7dcc9f315', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e3c19227-3720-4f19-8922-0c0c0f5fc9de', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 41, '2026-05-17 13:00:00+00', 'DR Congo', 'DR Congo', 'a8fcc1ed-f859-4cf8-8c75-47d8fb561cf8', '3bb819cc-0fc0-440f-8143-37e238066abb', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('12c63a4f-af19-4b0d-8204-ce373dd0e5f3', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 42, '2026-05-23 13:00:00+00', 'DR Congo', 'DR Congo', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'c7364492-3738-4ed6-8037-0ce2994929dd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('002549f7-49c4-4a0d-8d67-d4555a0f0ddf', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 43, '2026-05-23 13:00:00+00', 'DR Congo', 'DR Congo', 'a61e5411-af92-4ab7-84bb-26e158707d57', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('3719e862-14da-4ec5-8035-8847e770b09c', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 44, '2026-05-23 13:00:00+00', 'DR Congo', 'DR Congo', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', '1408bb64-3cac-4851-8c28-cbd7dcc9f315', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('58ef7b4a-29db-438e-829d-8199e66d2db3', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 45, '2026-05-23 13:00:00+00', 'DR Congo', 'DR Congo', '67ca285b-c737-46d2-8443-e2968a10eef9', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('fb1f3122-5257-4556-8b7b-a37d08f3713b', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 46, '2026-05-30 13:00:00+00', 'DR Congo', 'DR Congo', '954b4931-459b-46a6-812c-f34cd2b61a8b', 'c786e30d-cd92-4e7f-8784-a9b51dcdbaff', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('058be6e5-f611-41b9-80b6-de373ca6a339', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 47, '2026-05-30 13:00:00+00', 'DR Congo', 'DR Congo', 'c9724ee8-163b-4ef2-80fb-4822818d7908', 'feb89a5c-ebfe-487f-88c3-e2deac1c7c0a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('48cccecc-be94-4ff0-8d76-707199be0610', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 48, '2026-05-30 13:00:00+00', 'DR Congo', 'DR Congo', 'c7364492-3738-4ed6-8037-0ce2994929dd', 'd8c6a104-6acb-47a8-85c1-a52f11c3debc', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6bfe145d-8409-49d7-8b9b-3a2f17062bb8', 'ec0e015c-f2bd-41d0-8e53-69176b661a30', 'f7bbc34f-7f5c-42dc-89eb-7241ce36b7ac', 'Regular Season', 1, 49, '2026-05-30 13:00:00+00', 'DR Congo', 'DR Congo', 'a61e5411-af92-4ab7-84bb-26e158707d57', '67ca285b-c737-46d2-8443-e2968a10eef9', 'scheduled')
ON CONFLICT DO NOTHING;

-- Assign markets
INSERT INTO football.fixture_markets (fixture_id, market_id, outcomes)
SELECT f.id, pm.id,
  CASE pm.slug
    WHEN '1x2' THEN '["Home","Draw","Away"]'::jsonb
    WHEN 'btts' THEN '["Yes","No"]'::jsonb
    WHEN 'over-under-2-5' THEN '["Over 2.5","Under 2.5"]'::jsonb
  END
FROM football.fixtures f
CROSS JOIN football.prediction_markets pm
WHERE f.competition_id = 'ec0e015c-f2bd-41d0-8e53-69176b661a30'
  AND pm.slug IN ('1x2','btts','over-under-2-5')
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════════
-- ZSL
-- ══════════════════════════════════════════════════════════════════

INSERT INTO football.competitions (id, slug, name, short_name, competition_kind, region, country_code, country_name, organizer, gender, is_active)
VALUES ('93aace28-df45-4450-89d2-0bccc38f8405', 'zambia-super-league-2026', 'ZSL', 'ZSL', 'league', 'africa', 'ZM', 'Zambia', 'FAZ', 'male', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO football.seasons (id, competition_id, slug, label, year_start, year_end, starts_on, ends_on, status, is_active)
VALUES ('42290470-8a77-4966-8435-b166d04f6971', '93aace28-df45-4450-89d2-0bccc38f8405', 'zsl-2026', '2026', 2026, 2026, '2026-04-14', '2026-05-31', 'active', true)
ON CONFLICT (slug) DO NOTHING;

-- Teams (18)
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('68e83565-a06b-44ec-89f9-3d839ddf0791', 'nkwazi-fc', 'Nkwazi F.C.', 'NKW', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('88e605f0-3d83-4d53-8038-b7886a6016dd', 'napsa-stars-fc', 'NAPSA Stars F.C.', 'NAP', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('684c41fe-d789-4ae1-88e2-9323ce3ec9ff', 'nkana-fc', 'Nkana F.C.', 'NKA', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('afa500b9-023d-4c33-818e-01c547edfe50', 'mines-united-fc', 'Mines United FC', 'MIN', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('c498fad7-c546-453e-8df8-5235060b9105', 'mutondo-stars-fc', 'Mutondo Stars FC', 'MUT', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('da96c54a-af93-4b99-83ee-0595e7afa80c', 'green-eagles-fc', 'Green Eagles FC', 'GRE', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('10a166a6-29c5-48ec-8df1-f58edaa6f955', 'kabwe-warriors-fc', 'Kabwe Warriors F.C.', 'KAB', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('fac4eb80-d934-4c87-8084-13d80be871a1', 'power-dynamos-fc', 'Power Dynamos F.C.', 'POW', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('19045809-43e1-4466-8385-b15a27646cee', 'prison-leopards-fc', 'Prison Leopards FC', 'PRI', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('706a1ae5-0981-4ea3-8f10-3bd1074e460f', 'nchanga-rangers-fc', 'Nchanga Rangers F.C.', 'NCH', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('b794608c-96e6-4321-8659-85123efb958e', 'maestro-united-zambia', 'Maestro United Zambia', 'MAE', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('12af9ce0-bcc1-404e-880c-86dcc605f36a', 'green-buffaloes-fc', 'Green Buffaloes F.C.', 'GRE', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('5f3a10c9-9b2b-4de4-82bc-42e2366c9bbd', 'konkola-blades-fc', 'Konkola Blades F.C.', 'KON', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('1ad62e1b-182f-462d-8c80-b506d88a9823', 'mufulira-wanderers-fc', 'Mufulira Wanderers F.C.', 'MUF', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('e57aa2ff-58b9-46c7-88fd-852782b0ede5', 'kansanshi-dynamos-fc', 'Kansanshi Dynamos FC', 'KAN', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('b2140a2b-4e44-4330-88eb-c46d87f7bafb', 'zesco-united-fc', 'ZESCO United F.C.', 'ZES', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('6f86891a-cda5-40b0-8990-f592dba2ef2e', 'zanaco-fc', 'Zanaco F.C.', 'ZAN', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('a5b444ec-d129-4aab-8417-0d9940e4fc06', 'red-arrows-fc', 'Red Arrows F.C.', 'RED', 'club', 'ZM', 'Zambia', true)
ON CONFLICT (slug) DO NOTHING;

-- Fixtures (44)
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b7a44105-9285-42a7-8011-14ef84adc067', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 1, '2026-04-15 13:00:00+00', 'Zambia', 'Zambia', '68e83565-a06b-44ec-89f9-3d839ddf0791', '88e605f0-3d83-4d53-8038-b7886a6016dd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('db35faae-738b-44f1-8b77-2aaf6aa27d84', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 2, '2026-04-15 13:00:00+00', 'Zambia', 'Zambia', '684c41fe-d789-4ae1-88e2-9323ce3ec9ff', 'afa500b9-023d-4c33-818e-01c547edfe50', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('4c5546d1-db09-4676-8c0b-fa719cb04564', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 3, '2026-04-15 13:00:00+00', 'Zambia', 'Zambia', 'c498fad7-c546-453e-8df8-5235060b9105', 'da96c54a-af93-4b99-83ee-0595e7afa80c', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('08a5da19-98a9-40ab-8cec-9d7ff4c01bd6', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 4, '2026-04-16 13:00:00+00', 'Zambia', 'Zambia', '10a166a6-29c5-48ec-8df1-f58edaa6f955', 'fac4eb80-d934-4c87-8084-13d80be871a1', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('59e4ac04-3164-4deb-8394-200345ac44e0', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 5, '2026-04-16 13:00:00+00', 'Zambia', 'Zambia', '19045809-43e1-4466-8385-b15a27646cee', '706a1ae5-0981-4ea3-8f10-3bd1074e460f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('2de5ee76-f3b8-4f53-8629-5ae9fefb0a71', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 6, '2026-04-16 13:00:00+00', 'Zambia', 'Zambia', 'b794608c-96e6-4321-8659-85123efb958e', '12af9ce0-bcc1-404e-880c-86dcc605f36a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('a56b4de5-c2fe-4a6f-89fa-83b597d9f9c9', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 7, '2026-04-16 13:00:00+00', 'Zambia', 'Zambia', '5f3a10c9-9b2b-4de4-82bc-42e2366c9bbd', '1ad62e1b-182f-462d-8c80-b506d88a9823', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('c449646f-fc22-4985-8fdb-c1d287f1fe5f', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 8, '2026-04-16 13:00:00+00', 'Zambia', 'Zambia', 'e57aa2ff-58b9-46c7-88fd-852782b0ede5', 'b2140a2b-4e44-4330-88eb-c46d87f7bafb', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('adc390da-d391-446a-832c-75e2ae34b77e', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 9, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', '6f86891a-cda5-40b0-8990-f592dba2ef2e', 'afa500b9-023d-4c33-818e-01c547edfe50', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('3809db83-0479-4733-8b08-5e81d6106d71', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 10, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', '5f3a10c9-9b2b-4de4-82bc-42e2366c9bbd', 'fac4eb80-d934-4c87-8084-13d80be871a1', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6825a1ec-3b7c-478c-8395-9b6bb898ef18', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 11, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', 'da96c54a-af93-4b99-83ee-0595e7afa80c', '1ad62e1b-182f-462d-8c80-b506d88a9823', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('18f4174d-f35d-447e-84c5-20f6309ea72a', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 12, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', '684c41fe-d789-4ae1-88e2-9323ce3ec9ff', '706a1ae5-0981-4ea3-8f10-3bd1074e460f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('7cc1e4d6-9e6b-4788-8858-af0ee7a31784', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 13, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', 'c498fad7-c546-453e-8df8-5235060b9105', 'a5b444ec-d129-4aab-8417-0d9940e4fc06', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('940fc6ca-96d0-4285-86f8-335472bb8c58', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 14, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', '19045809-43e1-4466-8385-b15a27646cee', 'b794608c-96e6-4321-8659-85123efb958e', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9e203211-bc53-4786-8e6c-8a3b173a6057', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 15, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', '10a166a6-29c5-48ec-8df1-f58edaa6f955', '88e605f0-3d83-4d53-8038-b7886a6016dd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('1a4c3c41-3f35-4a44-82ee-8e922cb58a20', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 16, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', 'e57aa2ff-58b9-46c7-88fd-852782b0ede5', '12af9ce0-bcc1-404e-880c-86dcc605f36a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('bbf40223-a161-4eb2-84d9-f11841c63254', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 17, '2026-04-18 13:00:00+00', 'Zambia', 'Zambia', '68e83565-a06b-44ec-89f9-3d839ddf0791', 'b2140a2b-4e44-4330-88eb-c46d87f7bafb', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('88452eb3-c7fa-4932-8218-a03bccdcf8fb', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 18, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', '68e83565-a06b-44ec-89f9-3d839ddf0791', 'fac4eb80-d934-4c87-8084-13d80be871a1', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('823f1b5d-2ce3-427c-8b47-3dd6584f81a8', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 19, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', '706a1ae5-0981-4ea3-8f10-3bd1074e460f', '10a166a6-29c5-48ec-8df1-f58edaa6f955', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b48dbfcb-2280-42c8-88e9-f4f261a1a05c', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 20, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', 'b2140a2b-4e44-4330-88eb-c46d87f7bafb', '684c41fe-d789-4ae1-88e2-9323ce3ec9ff', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5804e36e-7763-470b-8a17-175095786354', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 21, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', 'b794608c-96e6-4321-8659-85123efb958e', '68e83565-a06b-44ec-89f9-3d839ddf0791', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('49d9309b-cf5a-4596-8ebc-73643ad5c1b3', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 22, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', '12af9ce0-bcc1-404e-880c-86dcc605f36a', '1ad62e1b-182f-462d-8c80-b506d88a9823', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e3b041b2-0c38-4bfc-8ddc-88b1963508da', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 23, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', 'fac4eb80-d934-4c87-8084-13d80be871a1', 'c498fad7-c546-453e-8df8-5235060b9105', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b7684cda-9204-43c0-8432-a7c5393b33f4', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 24, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', 'e57aa2ff-58b9-46c7-88fd-852782b0ede5', '19045809-43e1-4466-8385-b15a27646cee', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6494c570-8f76-413f-8a4a-176b3d794134', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 25, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', 'afa500b9-023d-4c33-818e-01c547edfe50', '5f3a10c9-9b2b-4de4-82bc-42e2366c9bbd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('95845904-f524-4638-829d-e6e2011a475c', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 26, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', '88e605f0-3d83-4d53-8038-b7886a6016dd', '6f86891a-cda5-40b0-8990-f592dba2ef2e', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('1329bab0-1a7c-46cf-8e39-c70d1e6a0045', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 27, '2026-04-22 13:00:00+00', 'Zambia', 'Zambia', 'a5b444ec-d129-4aab-8417-0d9940e4fc06', 'da96c54a-af93-4b99-83ee-0595e7afa80c', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('55fa698b-d419-4843-8b3a-6fb462b64126', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 28, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', 'a5b444ec-d129-4aab-8417-0d9940e4fc06', '5f3a10c9-9b2b-4de4-82bc-42e2366c9bbd', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('95cc9038-3b3e-401f-8aa2-2192af4ca5f2', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 29, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', '88e605f0-3d83-4d53-8038-b7886a6016dd', '684c41fe-d789-4ae1-88e2-9323ce3ec9ff', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5a1b543b-c505-4bd4-81af-f3f56da169de', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 30, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', '706a1ae5-0981-4ea3-8f10-3bd1074e460f', '68e83565-a06b-44ec-89f9-3d839ddf0791', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('47dbb5ce-07c9-4798-8b6b-01e18424fff5', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 31, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', '1ad62e1b-182f-462d-8c80-b506d88a9823', 'c498fad7-c546-453e-8df8-5235060b9105', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('49f27782-a89c-4513-864d-5edb10e1712d', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 32, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', 'fac4eb80-d934-4c87-8084-13d80be871a1', '6f86891a-cda5-40b0-8990-f592dba2ef2e', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('d10c4f67-1b0f-40d2-8576-fa020eef0442', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 33, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', '12af9ce0-bcc1-404e-880c-86dcc605f36a', 'da96c54a-af93-4b99-83ee-0595e7afa80c', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('37b721dc-c6b1-47b6-8970-b8d8b9e4d058', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 34, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', 'afa500b9-023d-4c33-818e-01c547edfe50', '10a166a6-29c5-48ec-8df1-f58edaa6f955', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('dfc46b2a-d65e-45cb-8326-74443f6c2b64', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 35, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', 'b2140a2b-4e44-4330-88eb-c46d87f7bafb', '19045809-43e1-4466-8385-b15a27646cee', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9f746d01-0769-4dd9-8e36-db4750f1deb4', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 36, '2026-04-29 13:00:00+00', 'Zambia', 'Zambia', 'b794608c-96e6-4321-8659-85123efb958e', 'e57aa2ff-58b9-46c7-88fd-852782b0ede5', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('ac810861-0d86-4585-823f-a2cd2ef23f2e', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 37, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', '19045809-43e1-4466-8385-b15a27646cee', '12af9ce0-bcc1-404e-880c-86dcc605f36a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('7915d48c-1e5d-42ec-811b-991b31cb7d95', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 38, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', 'c498fad7-c546-453e-8df8-5235060b9105', 'afa500b9-023d-4c33-818e-01c547edfe50', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('ee00af96-23be-47f4-859b-400caedf83a0', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 39, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', '684c41fe-d789-4ae1-88e2-9323ce3ec9ff', 'b794608c-96e6-4321-8659-85123efb958e', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('ed8a271a-24ec-46b7-8e24-d0109304203f', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 40, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', '1ad62e1b-182f-462d-8c80-b506d88a9823', 'a5b444ec-d129-4aab-8417-0d9940e4fc06', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('fce24978-b7f6-40aa-865b-39824453755c', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 41, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', '6f86891a-cda5-40b0-8990-f592dba2ef2e', '706a1ae5-0981-4ea3-8f10-3bd1074e460f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b4aa471e-e4c9-4477-8916-9b9b4b28f0be', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 42, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', '68e83565-a06b-44ec-89f9-3d839ddf0791', 'e57aa2ff-58b9-46c7-88fd-852782b0ede5', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('64552f20-1d66-4a9e-8fe0-b8c2634e4444', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 43, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', 'da96c54a-af93-4b99-83ee-0595e7afa80c', 'fac4eb80-d934-4c87-8084-13d80be871a1', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('2dcfd408-bf48-4b91-8085-116061ee84fd', '93aace28-df45-4450-89d2-0bccc38f8405', '42290470-8a77-4966-8435-b166d04f6971', 'Regular Season', 1, 44, '2026-05-02 13:00:00+00', 'Zambia', 'Zambia', '10a166a6-29c5-48ec-8df1-f58edaa6f955', 'b2140a2b-4e44-4330-88eb-c46d87f7bafb', 'scheduled')
ON CONFLICT DO NOTHING;

-- Assign markets
INSERT INTO football.fixture_markets (fixture_id, market_id, outcomes)
SELECT f.id, pm.id,
  CASE pm.slug
    WHEN '1x2' THEN '["Home","Draw","Away"]'::jsonb
    WHEN 'btts' THEN '["Yes","No"]'::jsonb
    WHEN 'over-under-2-5' THEN '["Over 2.5","Under 2.5"]'::jsonb
  END
FROM football.fixtures f
CROSS JOIN football.prediction_markets pm
WHERE f.competition_id = '93aace28-df45-4450-89d2-0bccc38f8405'
  AND pm.slug IN ('1x2','btts','over-under-2-5')
ON CONFLICT DO NOTHING;

-- ══════════════════════════════════════════════════════════════════
-- Rwanda Premier League
-- ══════════════════════════════════════════════════════════════════

INSERT INTO football.competitions (id, slug, name, short_name, competition_kind, region, country_code, country_name, organizer, gender, is_active)
VALUES ('bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', 'rwanda-premier-league-2026', 'Rwanda Premier League', 'RPL', 'league', 'africa', 'RW', 'Rwanda', 'FERWAFA', 'male', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO football.seasons (id, competition_id, slug, label, year_start, year_end, starts_on, ends_on, status, is_active)
VALUES ('3203df3a-681a-4395-8270-f4d7cbdc3636', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', 'rpl-2025-26', '2025-26', 2025, 2026, '2026-04-14', '2026-05-31', 'active', true)
ON CONFLICT (slug) DO NOTHING;

-- Teams (18)
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'gasogi-united', 'Gasogi United', 'GAS', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('94a1c498-dbaf-4fe2-854f-16f9766473c8', 'gorilla-fc', 'Gorilla FC', 'GOR', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('b70d4cbb-3531-436d-8403-9486ffdf545a', 'marines-fc', 'Marines FC', 'MAR', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', 'as-kigali', 'AS Kigali', 'AS ', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'musanze-fc', 'Musanze FC', 'MUS', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('40309ff0-ba6f-4b62-83b2-552b1927e81a', 'amagaju-fc', 'Amagaju FC', 'AMA', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('e84cf217-d70b-4b32-8e8d-8adc76c68daf', 'etincelles-fc', 'Etincelles FC', 'ETI', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('13065788-8055-4cf5-80a4-b313a71fc4e6', 'Rayon Sports-fc', 'Rayon Sports FC', 'Rayon Sports', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'gicumbi-fc', 'Gicumbi FC', 'GIC', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('cea79aa3-fd48-41de-8bcc-bd3728584caf', 'as-muhanga', 'AS Muhanga', 'AS ', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('f06e7c66-bc20-4590-855d-20270e86eb6a', 'mukura-victory-sports', 'Mukura Victory Sports', 'MUK', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'al-merreikh', 'Al-Merreikh', 'AL-', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'kiyovu-sports', 'Kiyovu Sports', 'KIY', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('6976c42b-24a6-4536-87b3-7c09c5a08e70', 'al-hilal-omdurman', 'Al-Hilal Omdurman', 'AL-', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('f86a09c4-75d7-43e4-8b34-21015b4ec843', 'police-fc', 'Police FC', 'POL', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('c1222ec0-9e00-4966-8877-7b873e63478f', 'bugesera-fc', 'Bugesera FC', 'BUG', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('a64cb34e-40f7-4b8b-89b9-3fc7fd082863', 'rutsiro-fc', 'Rutsiro FC', 'RUT', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;
INSERT INTO football.teams (id, slug, name, short_name, team_type, country_code, country_name, is_active)
VALUES ('2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'rayon-sports', 'Rayon Sports', 'RAY', 'club', 'RW', 'Rwanda', true)
ON CONFLICT (slug) DO NOTHING;

-- Fixtures (72)
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('06ca57b0-e264-43a8-8703-6f919af853e6', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 1, '2026-04-17 13:00:00+00', 'Rwanda', 'Rwanda', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', '94a1c498-dbaf-4fe2-854f-16f9766473c8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('908adc74-84fa-483c-8ee7-9b1b034930ef', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 2, '2026-04-17 13:00:00+00', 'Rwanda', 'Rwanda', 'b70d4cbb-3531-436d-8403-9486ffdf545a', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6d28b518-7eb4-4d16-8883-b89151deb4c8', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 3, '2026-04-17 13:00:00+00', 'Rwanda', 'Rwanda', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', '40309ff0-ba6f-4b62-83b2-552b1927e81a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('bd5ae359-12de-489c-8ed1-e6c90e27ab4d', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 4, '2026-04-18 13:00:00+00', 'Rwanda', 'Rwanda', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', '13065788-8055-4cf5-80a4-b313a71fc4e6', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('ecb630e3-fddc-4580-8c9d-43d855d5f063', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 5, '2026-04-18 13:00:00+00', 'Rwanda', 'Rwanda', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('193693bc-b9c1-4cec-8a44-f1bf594fbd43', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 6, '2026-04-18 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('aa50b7b3-01d2-47cc-814d-674a2e8a2a51', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 7, '2026-04-18 13:00:00+00', 'Rwanda', 'Rwanda', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', '6976c42b-24a6-4536-87b3-7c09c5a08e70', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('50d202b8-0442-45c3-8a14-16c28ab9c071', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 8, '2026-04-19 13:00:00+00', 'Rwanda', 'Rwanda', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('1ea70da4-cf1b-4480-8d26-25b1504134ac', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 9, '2026-04-19 13:00:00+00', 'Rwanda', 'Rwanda', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('28e87076-5962-4190-80b2-1a70d4c0aeba', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 10, '2026-04-24 13:00:00+00', 'Rwanda', 'Rwanda', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('eafd78b9-3702-425b-8655-c83299480b86', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 11, '2026-04-24 13:00:00+00', 'Rwanda', 'Rwanda', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', '94a1c498-dbaf-4fe2-854f-16f9766473c8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('d43e70e1-6fb9-408d-8fab-39d034c21f1d', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 12, '2026-04-24 13:00:00+00', 'Rwanda', 'Rwanda', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5c799fad-b86d-462e-8e40-839e6cd7729c', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 13, '2026-04-25 13:00:00+00', 'Rwanda', 'Rwanda', '6976c42b-24a6-4536-87b3-7c09c5a08e70', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('7da22772-79d9-4f9a-8cd5-99baac2ae227', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 14, '2026-04-25 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', '13065788-8055-4cf5-80a4-b313a71fc4e6', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5419047b-1e68-48bf-8964-f11f0c5a5fa7', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 15, '2026-04-25 13:00:00+00', 'Rwanda', 'Rwanda', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'b70d4cbb-3531-436d-8403-9486ffdf545a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('79e55119-aee2-4a03-8aca-a656ec01d196', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 16, '2026-04-26 13:00:00+00', 'Rwanda', 'Rwanda', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e04679ec-bc96-4565-89ea-f7eb78c54250', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 17, '2026-04-26 13:00:00+00', 'Rwanda', 'Rwanda', '40309ff0-ba6f-4b62-83b2-552b1927e81a', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9811d307-437d-4d66-894a-3199409f70ad', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 18, '2026-04-26 13:00:00+00', 'Rwanda', 'Rwanda', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6fc8b240-0324-4f88-87ed-c5cee81e387e', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 19, '2026-05-01 13:00:00+00', 'Rwanda', 'Rwanda', 'b70d4cbb-3531-436d-8403-9486ffdf545a', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5241bace-6ce3-48f2-8fab-5eb85d82c2bc', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 20, '2026-05-01 13:00:00+00', 'Rwanda', 'Rwanda', '94a1c498-dbaf-4fe2-854f-16f9766473c8', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('439341d0-4182-45b8-85aa-2e0592a6ba2b', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 21, '2026-05-02 13:00:00+00', 'Rwanda', 'Rwanda', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', '40309ff0-ba6f-4b62-83b2-552b1927e81a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('cb68b8db-b133-451f-8a25-0d3b6c3a98a4', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 22, '2026-05-02 13:00:00+00', 'Rwanda', 'Rwanda', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e0b5b5f7-8b19-46a5-89fb-f529474497cf', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 23, '2026-05-02 13:00:00+00', 'Rwanda', 'Rwanda', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', '13065788-8055-4cf5-80a4-b313a71fc4e6', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('99b84d42-def4-445a-8827-5555c510dd84', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 24, '2026-05-03 13:00:00+00', 'Rwanda', 'Rwanda', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', '6976c42b-24a6-4536-87b3-7c09c5a08e70', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6b151112-27c6-44dc-8cd4-31f0e17f3518', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 25, '2026-05-03 13:00:00+00', 'Rwanda', 'Rwanda', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('60d4f2a6-186d-4384-83b1-be2dce3d6ea5', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 26, '2026-05-03 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('4b936c2f-1f18-4a92-81b1-7a6aadfaf22d', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 27, '2026-05-03 13:00:00+00', 'Rwanda', 'Rwanda', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e72fb512-2c92-41c1-8b5f-f64415f4a24d', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 28, '2026-05-05 13:00:00+00', 'Rwanda', 'Rwanda', '40309ff0-ba6f-4b62-83b2-552b1927e81a', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('436618d0-82b1-4fc0-8d7b-bc670c9309cd', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 29, '2026-05-05 13:00:00+00', 'Rwanda', 'Rwanda', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('d688cfb9-0bdc-4ae8-81d6-d205a98d6f93', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 30, '2026-05-06 13:00:00+00', 'Rwanda', 'Rwanda', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'b70d4cbb-3531-436d-8403-9486ffdf545a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('d4b9a0d1-942e-4544-81a2-5b30fe2958b1', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 31, '2026-05-06 13:00:00+00', 'Rwanda', 'Rwanda', '94a1c498-dbaf-4fe2-854f-16f9766473c8', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('7d21c3bc-a773-4f29-80bd-0c5f33d6c85a', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 32, '2026-05-06 13:00:00+00', 'Rwanda', 'Rwanda', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9346820c-19fe-4c01-814a-0479d6ac0a02', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 33, '2026-05-06 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('63890e5d-f83f-4c52-8831-cba8b612133c', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 34, '2026-05-06 13:00:00+00', 'Rwanda', 'Rwanda', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('71fec37e-4d67-4db7-8b27-1186a756e2c5', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 35, '2026-05-06 13:00:00+00', 'Rwanda', 'Rwanda', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('91c5125d-d581-44cd-8517-a40f6802610b', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 36, '2026-05-07 13:00:00+00', 'Rwanda', 'Rwanda', '13065788-8055-4cf5-80a4-b313a71fc4e6', '6976c42b-24a6-4536-87b3-7c09c5a08e70', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('d17c231c-1cca-403e-8bb1-f61d8225ef4b', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 37, '2026-05-09 13:00:00+00', 'Rwanda', 'Rwanda', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('c36f6f32-f4a6-4902-859f-1c245d75602f', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 38, '2026-05-09 13:00:00+00', 'Rwanda', 'Rwanda', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('29ccedfe-8c39-4738-856b-8a1846f82d9f', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 39, '2026-05-09 13:00:00+00', 'Rwanda', 'Rwanda', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', '40309ff0-ba6f-4b62-83b2-552b1927e81a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('f58f2cb7-57a4-4b1a-895f-1e21658fa61d', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 40, '2026-05-09 13:00:00+00', 'Rwanda', 'Rwanda', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('ac707638-cb5b-4df0-8f3c-a65dc6c20a66', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 41, '2026-05-09 13:00:00+00', 'Rwanda', 'Rwanda', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'b70d4cbb-3531-436d-8403-9486ffdf545a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b395b691-c32e-4a2d-8716-e6361fae1f14', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 42, '2026-05-10 13:00:00+00', 'Rwanda', 'Rwanda', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('c764dbf8-4d57-41e0-855e-629db1771b90', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 43, '2026-05-10 13:00:00+00', 'Rwanda', 'Rwanda', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', '6976c42b-24a6-4536-87b3-7c09c5a08e70', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('4eaab61e-1ca9-4a99-8a38-3b3d92b6b501', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 44, '2026-05-10 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', '94a1c498-dbaf-4fe2-854f-16f9766473c8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('dab6f446-6857-4c24-8a56-d5d51b3d866f', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 45, '2026-05-10 13:00:00+00', 'Rwanda', 'Rwanda', '13065788-8055-4cf5-80a4-b313a71fc4e6', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6324cdad-a18c-4245-8708-5a6540e59e56', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 46, '2026-05-15 13:00:00+00', 'Rwanda', 'Rwanda', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('88e216a3-d29e-421a-89e1-70f0942e9279', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 47, '2026-05-15 13:00:00+00', 'Rwanda', 'Rwanda', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', '94a1c498-dbaf-4fe2-854f-16f9766473c8', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('c98a534e-fe3b-4686-8710-33f8afd14f70', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 48, '2026-05-16 13:00:00+00', 'Rwanda', 'Rwanda', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('0a788e42-230c-4722-8588-93f392fb7f96', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 49, '2026-05-16 13:00:00+00', 'Rwanda', 'Rwanda', 'b70d4cbb-3531-436d-8403-9486ffdf545a', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('b4ce8946-ee94-4229-819d-a594f9d6c15c', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 50, '2026-05-16 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9ec6b1cf-f50b-41df-8ed2-f7de2c900a4e', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 51, '2026-05-16 13:00:00+00', 'Rwanda', 'Rwanda', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', '6976c42b-24a6-4536-87b3-7c09c5a08e70', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('01f32182-d7b0-4bd1-8184-5b8a59f4429c', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 52, '2026-05-17 13:00:00+00', 'Rwanda', 'Rwanda', '40309ff0-ba6f-4b62-83b2-552b1927e81a', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6b2aa282-50ba-4816-88c1-6ddce2c79950', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 53, '2026-05-17 13:00:00+00', 'Rwanda', 'Rwanda', '13065788-8055-4cf5-80a4-b313a71fc4e6', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('6c956310-44b3-446a-87fd-c2ba03b19d63', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 54, '2026-05-17 13:00:00+00', 'Rwanda', 'Rwanda', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('5dd0a619-cd5b-4176-8a3d-2738bb2ad88b', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 55, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', '6976c42b-24a6-4536-87b3-7c09c5a08e70', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('47839ac5-3b1e-484c-8e0a-fe03ef59f9df', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 56, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', '13065788-8055-4cf5-80a4-b313a71fc4e6', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('d64e9e1d-94d9-45a0-8c17-9573aae717cb', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 57, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', '40309ff0-ba6f-4b62-83b2-552b1927e81a', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('dca7795b-ddcb-4d05-8a61-0e45d4dc7bd7', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 58, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'f06e7c66-bc20-4590-855d-20270e86eb6a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('af638547-bb0d-4d70-8a21-ef03f1ae2acd', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 59, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', '94a1c498-dbaf-4fe2-854f-16f9766473c8', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('2fd3eaba-282d-4472-89c3-71e8c3c9974a', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 60, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', 'b70d4cbb-3531-436d-8403-9486ffdf545a', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('7baa0170-8adf-49bd-8674-dabebeb1d316', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 61, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('0feb3003-62a9-4da3-83e1-10614c570af4', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 62, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('a8b30b5c-276d-4230-8763-2a4805921fee', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 63, '2026-05-24 13:00:00+00', 'Rwanda', 'Rwanda', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('eed4e5a7-221b-45fe-817a-fa4a8db32ee7', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 64, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', '13065788-8055-4cf5-80a4-b313a71fc4e6', 'e4d5d7dc-b704-4f3c-8974-12e9a558a74d', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('861810e4-79be-4daa-8622-f6df5f70fa39', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 65, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', '2cd0a28f-f7c9-469a-8bb9-2edb3676bc80', '1410b3e7-2214-40b3-81c3-5da5d0b9efc2', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9c807ffb-3d2a-404b-82ae-8bd63bf2923f', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 66, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', 'e84cf217-d70b-4b32-8e8d-8adc76c68daf', '6976c42b-24a6-4536-87b3-7c09c5a08e70', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('523d9349-c757-47fd-8847-5e0213d260ea', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 67, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', '4aec394b-3151-4ae4-82e9-0b6a4b781a17', 'f86a09c4-75d7-43e4-8b34-21015b4ec843', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('e9cf9d9a-b199-4747-8a17-8124e67fa582', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 68, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', '94a1c498-dbaf-4fe2-854f-16f9766473c8', '98658c20-5fe6-4ae4-8010-de2b30f1d29a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('202046d6-6b2b-415c-82b0-9b5d30ec78f8', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 69, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', 'b70d4cbb-3531-436d-8403-9486ffdf545a', 'cea79aa3-fd48-41de-8bcc-bd3728584caf', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('9152e9db-f13c-4745-85ca-360c05d692f5', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 70, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', 'f06e7c66-bc20-4590-855d-20270e86eb6a', '40309ff0-ba6f-4b62-83b2-552b1927e81a', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('71dd7234-2a9e-4647-8ea8-bdb6e241cff0', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 71, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', '2f1aeb08-17c8-4293-8e5b-d1fbe387152b', 'fc4114ea-33f2-49e1-8fd3-ebb36fa87618', 'scheduled')
ON CONFLICT DO NOTHING;
INSERT INTO football.fixtures (id, competition_id, season_id, stage_name, matchday, fixture_number, kickoff_at, venue_city, venue_country, home_team_id, away_team_id, status)
VALUES ('35483a26-2698-46a9-8672-0cbf72e90621', 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36', '3203df3a-681a-4395-8270-f4d7cbdc3636', 'Regular Season', 1, 72, '2026-05-31 13:00:00+00', 'Rwanda', 'Rwanda', 'a64cb34e-40f7-4b8b-89b9-3fc7fd082863', 'c1222ec0-9e00-4966-8877-7b873e63478f', 'scheduled')
ON CONFLICT DO NOTHING;

-- Assign markets
INSERT INTO football.fixture_markets (fixture_id, market_id, outcomes)
SELECT f.id, pm.id,
  CASE pm.slug
    WHEN '1x2' THEN '["Home","Draw","Away"]'::jsonb
    WHEN 'btts' THEN '["Yes","No"]'::jsonb
    WHEN 'over-under-2-5' THEN '["Over 2.5","Under 2.5"]'::jsonb
  END
FROM football.fixtures f
CROSS JOIN football.prediction_markets pm
WHERE f.competition_id = 'bd3c9c62-3a1b-4c24-832f-4bfdbe1f9d36'
  AND pm.slug IN ('1x2','btts','over-under-2-5')
ON CONFLICT DO NOTHING;

