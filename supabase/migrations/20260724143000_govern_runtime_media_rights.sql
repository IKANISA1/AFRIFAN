-- Fail-closed runtime-media provenance for the mobile surfaces governed by
-- DESIGN.md. This migration is source-only until an isolated, authorized
-- database validation and deployment is approved.

alter table public.news_articles
  add column if not exists image_provenance_id text,
  add column if not exists image_rights_approved boolean not null default false,
  add column if not exists image_rights_approved_at timestamptz,
  add column if not exists image_rights_approved_by uuid;

alter table public.shop_products
  add column if not exists image_provenance_id text,
  add column if not exists image_rights_approved boolean not null default false,
  add column if not exists image_rights_approved_at timestamptz,
  add column if not exists image_rights_approved_by uuid;

alter table public.matches
  add column if not exists image_provenance_id text,
  add column if not exists image_rights_approved boolean not null default false,
  add column if not exists image_rights_approved_at timestamptz,
  add column if not exists image_rights_approved_by uuid,
  add column if not exists home_team_logo_provenance_id text,
  add column if not exists home_team_logo_rights_approved boolean not null
    default false,
  add column if not exists away_team_logo_provenance_id text,
  add column if not exists away_team_logo_rights_approved boolean not null
    default false;

alter table public.news_articles
  drop constraint if exists news_articles_approved_media_has_provenance,
  add constraint news_articles_approved_media_has_provenance check (
    not image_rights_approved
    or (
      nullif(btrim(image_provenance_id), '') is not null
      and image_rights_approved_at is not null
      and image_rights_approved_by is not null
    )
  );

alter table public.shop_products
  drop constraint if exists shop_products_approved_media_has_provenance,
  add constraint shop_products_approved_media_has_provenance check (
    not image_rights_approved
    or (
      nullif(btrim(image_provenance_id), '') is not null
      and image_rights_approved_at is not null
      and image_rights_approved_by is not null
    )
  );

alter table public.matches
  drop constraint if exists matches_approved_media_has_provenance,
  add constraint matches_approved_media_has_provenance check (
    (
      not image_rights_approved
      or (
        nullif(btrim(image_provenance_id), '') is not null
        and image_rights_approved_at is not null
        and image_rights_approved_by is not null
      )
    )
    and (
      not home_team_logo_rights_approved
      or nullif(btrim(home_team_logo_provenance_id), '') is not null
    )
    and (
      not away_team_logo_rights_approved
      or nullif(btrim(away_team_logo_provenance_id), '') is not null
    )
  );

comment on column public.news_articles.image_provenance_id is
  'Stable source/right-to-use register identifier; never a private asset URL.';
comment on column public.news_articles.image_rights_approved is
  'Fail-closed release authority. A URL alone is not approval.';
comment on column public.shop_products.image_provenance_id is
  'Stable source/right-to-use register identifier; never a private asset URL.';
comment on column public.shop_products.image_rights_approved is
  'Fail-closed release authority. A URL alone is not approval.';
comment on column public.matches.image_provenance_id is
  'Stable source/right-to-use register identifier for the hero image.';
comment on column public.matches.image_rights_approved is
  'Fail-closed release authority for the hero image.';
