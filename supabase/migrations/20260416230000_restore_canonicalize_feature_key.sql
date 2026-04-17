-- Restore the canonicalize_platform_feature_key helper in environments
-- where the hardening migration (180000) was only partially applied.
-- This function is required by get_feature_access_state.

CREATE OR REPLACE FUNCTION public.canonicalize_platform_feature_key(p_key text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(lower(trim(coalesce(p_key, ''))), '[^a-z0-9]+', '_', 'g');
$$;

COMMENT ON FUNCTION public.canonicalize_platform_feature_key IS
  'Normalizes feature keys for case-insensitive, punctuation-insensitive matching.';

-- Index for fast canonical lookup
CREATE INDEX IF NOT EXISTS idx_platform_features_canonical_lookup
  ON public.platform_features (
    public.canonicalize_platform_feature_key(feature_key),
    club_id
  );

-- Grant execute to anon and authenticated
REVOKE ALL ON FUNCTION public.canonicalize_platform_feature_key(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.canonicalize_platform_feature_key(text) TO anon, authenticated;
