-- Fix PL/pgSQL output-column shadowing inside fet_get_leaderboard().

CREATE OR REPLACE FUNCTION public.fet_get_leaderboard(
  p_club_id bigint DEFAULT NULL::bigint,
  p_limit integer DEFAULT 10
) RETURNS TABLE(
  rank integer,
  user_id uuid,
  supporter_alias text,
  display_name text,
  total_fet integer,
  tier text,
  is_current_user boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_club_id bigint;
  v_limit integer := GREATEST(COALESCE(p_limit, 10), 1);
BEGIN
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  IF v_club_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH ranked_rows AS (
    SELECT
      ROW_NUMBER() OVER (
        ORDER BY fm.points DESC, fm.joined_at ASC, fm.user_id ASC
      )::integer AS rank,
      fm.user_id,
      COALESCE(
        NULLIF(BTRIM(pr.public_user_id), ''),
        NULLIF(BTRIM(fm.display_name), ''),
        NULLIF(BTRIM(u.public_user_id), ''),
        '000000'
      ) AS supporter_alias,
      COALESCE(
        NULLIF(BTRIM(pr.display_name), ''),
        NULLIF(BTRIM(fm.display_name), ''),
        NULLIF(BTRIM(u.full_name), ''),
        'Supporter'
      ) AS display_name,
      GREATEST(COALESCE(fm.points, 0), 0)::integer AS total_fet,
      COALESCE(
        NULLIF(BTRIM(fm.tier), ''),
        public.resolve_fan_tier(GREATEST(COALESCE(fm.points, 0), 0))
      ) AS tier,
      (fm.user_id = auth.uid()) AS is_current_user
    FROM public.fan_memberships AS fm
    LEFT JOIN public.profiles AS pr
      ON pr.id = fm.user_id
    LEFT JOIN public.users AS u
      ON u.id = fm.user_id
    WHERE fm.club_id = v_club_id
  ),
  top_rows AS (
    SELECT *
    FROM ranked_rows
    ORDER BY rank ASC
    LIMIT v_limit
  ),
  current_row AS (
    SELECT *
    FROM ranked_rows AS ranked_entry
    WHERE ranked_entry.user_id = auth.uid()
      AND NOT EXISTS (
        SELECT 1
        FROM top_rows
        WHERE top_rows.user_id = auth.uid()
      )
  )
  SELECT
    combined.rank,
    combined.user_id,
    combined.supporter_alias,
    combined.display_name,
    combined.total_fet,
    combined.tier,
    combined.is_current_user
  FROM (
    SELECT * FROM top_rows
    UNION ALL
    SELECT * FROM current_row
  ) AS combined
  ORDER BY combined.rank ASC;
END;
$$;

NOTIFY pgrst, 'reload schema';
