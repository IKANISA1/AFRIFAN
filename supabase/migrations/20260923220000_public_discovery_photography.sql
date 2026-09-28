-- Explicitly approved photography for public player and community discovery.
-- Existing club-scoped/active row policies remain in force; no write grants.
alter table public.fan_clubs
  add column published_image_url text,
  add column image_rights_approved boolean not null default false,
  add column image_provenance_id text,
  add constraint fan_clubs_published_media_check check (published_image_url is null or (
    published_image_url ~ '^https://[^/@[:space:]]+'
    and image_rights_approved and nullif(btrim(image_provenance_id),'') is not null));
alter table public.squad_players
  add column published_image_url text,
  add column image_rights_approved boolean not null default false,
  add column image_provenance_id text,
  add constraint squad_players_published_media_check check (published_image_url is null or (
    published_image_url ~ '^https://[^/@[:space:]]+'
    and image_rights_approved and nullif(btrim(image_provenance_id),'') is not null));
grant select (published_image_url) on public.fan_clubs, public.squad_players to anon, authenticated;

alter table public.club_partner_publications add column image_url text;
alter table public.club_partner_publications
  add constraint club_partner_publications_editorial_media_check
  check (image_url is null or (
    image_url ~ '^https://[^/@[:space:]]+'
    and image_rights_approved
    and nullif(btrim(image_provenance_id), '') is not null
  ));
grant select (image_url) on public.club_partner_publications to anon, authenticated;

-- Home needs a public preview without predict_dashboard's welcome-wallet effect.
create function public.predict_public_preview(p_club_id bigint)
returns table(id uuid, home_team text, away_team text, home_crest text,
 away_crest text, competition text, kickoff_at timestamptz, locks_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select f.id,h.name,a.name,h.crest_url,a.crest_url,c.name,f.kickoff_at,
    least(p.locks_at,f.kickoff_at)
  from football.predict_pools p
  join football.predict_settings s on s.club_id=p.club_id and s.enabled
  join football.fixtures f on f.id=p.fixture_id
  join football.competitions c on c.id=f.competition_id
  join football.teams h on h.id=f.home_team_id
  join football.teams a on a.id=f.away_team_id
  where p.club_id=public.fet_resolve_public_club_id(p_club_id)
    and p.status='open' and p.opens_at<=now() and p.locks_at>now()
    and f.status='scheduled' and f.kickoff_at>now()
    and c.is_active and h.is_active and a.is_active
    and nullif(h.crest_url,'') is not null and nullif(a.crest_url,'') is not null
  order by f.kickoff_at,f.id limit 3;
$$;
revoke all on function public.predict_public_preview(bigint) from public;
grant execute on function public.predict_public_preview(bigint) to anon, authenticated;

-- Preserve the match feed while carrying its existing editorial approval.
-- No publication/write permission is added; clients hide unapproved images.
grant select (image_provenance_id, image_rights_approved) on public.matches to anon, authenticated;
CREATE OR REPLACE VIEW "public"."unified_matches" WITH ("security_invoker"='true') AS
 SELECT COALESCE("m"."id", "f"."id") AS "id",
    "f"."id" AS "fixture_id",
    "m"."id" AS "legacy_match_id",
    "m"."club_id",
    COALESCE("f"."home_team_name", "m"."home_team") AS "home_team",
    COALESCE("f"."away_team_name", "m"."away_team") AS "away_team",
    COALESCE("f"."competition_name", "m"."competition") AS "competition",
    COALESCE("f"."venue_name", "m"."venue") AS "venue",
    COALESCE(("f"."kickoff_at")::"date", "m"."match_date") AS "match_date",
    COALESCE(("f"."kickoff_at")::time without time zone, "m"."kickoff_time") AS "kickoff_time",
    "f"."kickoff_at",
    COALESCE("m"."is_on_sale", false) AS "is_on_sale",
    COALESCE("m"."ticket_general_price", 0) AS "ticket_general_price",
    COALESCE("m"."ticket_vip_price", 0) AS "ticket_vip_price",
    COALESCE(("f"."status")::"text", "m"."match_status") AS "match_status",
    COALESCE("f"."home_score", "m"."home_score") AS "home_score",
    COALESCE("f"."away_score", "m"."away_score") AS "away_score",
    COALESCE("f"."live_elapsed", "m"."live_minute") AS "live_minute",
    "m"."live_stats",
    "m"."live_events",
    "m"."image_url",
    COALESCE("m"."is_featured", false) AS "is_featured",
    "m"."capacity",
    "m"."sold_count",
    "f"."competition_slug",
    "f"."season_slug",
    "f"."home_team_logo",
    "f"."away_team_logo",
    "f"."competition_logo",
    "f"."home_team_logo_url" AS "home_team_crest_url",
    "f"."away_team_logo_url" AS "away_team_crest_url",
    "f"."home_team_slug",
    "f"."away_team_slug",
    "f"."home_team_short_name",
    "f"."away_team_short_name",
    "f"."api_status_short",
    "f"."external_fixture_id",
    "m"."image_provenance_id",
    COALESCE("m"."image_rights_approved", false) AS "image_rights_approved"
   FROM ("public"."football_fixtures_catalog" "f"
     LEFT JOIN "public"."matches" "m" ON ((("m"."fixture_id" = "f"."id") OR (("m"."fixture_id" IS NULL) AND ("m"."match_date" = ("f"."kickoff_at")::"date") AND ("lower"(TRIM(BOTH FROM COALESCE("m"."home_team", ''::"text"))) = "lower"(TRIM(BOTH FROM COALESCE("f"."home_team_name", ''::"text")))) AND ("lower"(TRIM(BOTH FROM COALESCE("m"."away_team", ''::"text"))) = "lower"(TRIM(BOTH FROM COALESCE("f"."away_team_name", ''::"text")))) AND ((NULLIF(TRIM(BOTH FROM COALESCE("m"."competition", ''::"text")), ''::"text") IS NULL) OR ("lower"(TRIM(BOTH FROM "m"."competition")) = "lower"(TRIM(BOTH FROM COALESCE("f"."competition_name", ''::"text")))))))));
