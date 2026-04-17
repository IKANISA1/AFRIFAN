-- Preserve explicit supporter membership tiers when admin workflows set them.
-- The existing trigger normalized tier from points on every write, which
-- prevented approved membership applications from persisting paid tiers such as
-- gold or platinum unless the supporter had also earned the matching point band.

CREATE OR REPLACE FUNCTION public.rs_sync_membership_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v_explicit_tier text := lower(btrim(coalesce(new.tier, '')));
BEGIN
  new.points := greatest(coalesce(new.points, 0), 0);

  IF v_explicit_tier IN ('fan', 'bronze', 'gold', 'platinum') THEN
    new.tier := v_explicit_tier;
  ELSE
    new.tier := CASE
      WHEN new.points >= 5000 THEN 'platinum'
      WHEN new.points >= 2000 THEN 'gold'
      WHEN new.points >= 1000 THEN 'bronze'
      ELSE 'fan'
    END;
  END IF;

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
