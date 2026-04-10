-- Repair historical environments where user_fcm_tokens existed before the
-- UNIQUE(token) contract was added. This keeps PostgREST upserts on
-- onConflict=token working across upgraded deployments.

DO $$
BEGIN
  IF to_regclass('public.user_fcm_tokens') IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.user_fcm_tokens stale
  USING public.user_fcm_tokens newer
  WHERE stale.token = newer.token
    AND stale.id < newer.id;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'user_fcm_tokens'
      AND indexname = 'idx_user_fcm_tokens_token_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_user_fcm_tokens_token_unique
      ON public.user_fcm_tokens (token);
  END IF;
END
$$;
