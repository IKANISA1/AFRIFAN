BEGIN;

CREATE OR REPLACE FUNCTION public.compat_parse_partner_id(p_partner_id uuid)
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  SELECT afc.id
  FROM public.partners p
  JOIN public.african_football_clubs afc
    ON (
      lower(regexp_replace(coalesce(afc.club_name, ''), '[^a-z0-9]+', '', 'g')) =
      lower(regexp_replace(coalesce(p.name, ''), '[^a-z0-9]+', '', 'g'))
    )
    OR (
      lower(regexp_replace(coalesce(afc.club_slug, ''), '[^a-z0-9]+', '', 'g')) =
      lower(regexp_replace(coalesce(p.slug, ''), '[^a-z0-9]+', '', 'g'))
    )
  WHERE p.id = p_partner_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.rs_sync_membership_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  new.points := greatest(coalesce(new.points, 0), 0);
  new.tier := CASE
    WHEN new.points >= 5000 THEN 'platinum'
    WHEN new.points >= 2000 THEN 'gold'
    WHEN new.points >= 1000 THEN 'bronze'
    ELSE 'fan'
  END;
  new.chapter := coalesce(nullif(btrim(coalesce(new.chapter, '')), ''), 'Kigali Central');
  new.display_name := public.rs_resolve_public_identity(new.user_id, new.display_name);

  IF coalesce(nullif(btrim(coalesce(new.membership_number, '')), ''), '') = '' THEN
    new.membership_number := 'RS-' ||
      to_char(coalesce(new.joined_at, now()), 'YYYY') ||
      '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  END IF;

  IF tg_op = 'INSERT' THEN
    new.created_at := coalesce(new.created_at, now());
    new.joined_at := coalesce(new.joined_at, new.created_at, now());
  END IF;

  new.updated_at := now();
  RETURN new;
END;
$$;

ALTER TABLE public.fan_memberships
  DROP CONSTRAINT IF EXISTS rs_fan_memberships_tier_check;

ALTER TABLE public.membership_packages
  DROP CONSTRAINT IF EXISTS rs_membership_packages_tier_check;

UPDATE public.fan_memberships
SET tier = CASE lower(coalesce(tier, ''))
  WHEN 'blue' THEN 'fan'
  WHEN 'silver' THEN 'bronze'
  ELSE lower(coalesce(tier, ''))
END
WHERE lower(coalesce(tier, '')) IN ('blue', 'silver', 'fan', 'bronze', 'gold', 'platinum');

UPDATE public.membership_packages
SET tier = CASE lower(coalesce(tier, ''))
  WHEN 'blue' THEN 'fan'
  WHEN 'silver' THEN 'bronze'
  ELSE lower(coalesce(tier, ''))
END
WHERE lower(coalesce(tier, '')) IN ('blue', 'silver', 'fan', 'bronze', 'gold', 'platinum');

ALTER TABLE public.fan_memberships
  ALTER COLUMN tier SET DEFAULT 'fan';

ALTER TABLE public.fan_memberships
  ADD CONSTRAINT rs_fan_memberships_tier_check
  CHECK (tier = ANY (ARRAY['fan'::text, 'bronze'::text, 'gold'::text, 'platinum'::text]));

ALTER TABLE public.membership_packages
  ADD CONSTRAINT rs_membership_packages_tier_check
  CHECK (tier = ANY (ARRAY['fan'::text, 'bronze'::text, 'gold'::text, 'platinum'::text]));

CREATE OR REPLACE FUNCTION public.cool_status_tier_for_points(p_points integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT CASE
    WHEN greatest(coalesce(p_points, 0), 0) >= 5000 THEN 'platinum'
    WHEN greatest(coalesce(p_points, 0), 0) >= 2000 THEN 'gold'
    WHEN greatest(coalesce(p_points, 0), 0) >= 1000 THEN 'bronze'
    ELSE 'fan'
  END;
$$;

CREATE OR REPLACE FUNCTION public.rs_membership_tier_for_points(p_points integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $$
  SELECT CASE
    WHEN greatest(coalesce(p_points, 0), 0) >= 5000 THEN 'platinum'
    WHEN greatest(coalesce(p_points, 0), 0) >= 2000 THEN 'gold'
    WHEN greatest(coalesce(p_points, 0), 0) >= 1000 THEN 'bronze'
    ELSE 'fan'
  END;
$$;

COMMIT;
