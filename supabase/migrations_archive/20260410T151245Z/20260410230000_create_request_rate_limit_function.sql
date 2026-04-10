CREATE TABLE IF NOT EXISTS public.request_rate_limits (
  bucket_key text PRIMARY KEY,
  count integer NOT NULL DEFAULT 0 CHECK (count >= 0),
  reset_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_request_rate_limits_reset_at
  ON public.request_rate_limits (reset_at);

ALTER TABLE public.request_rate_limits ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.request_rate_limits FROM anon, authenticated;
GRANT ALL ON public.request_rate_limits TO service_role;

CREATE OR REPLACE FUNCTION public.consume_request_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_ms integer
)
RETURNS TABLE (
  allowed boolean,
  retry_after_seconds integer,
  remaining integer,
  reset_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  now_ts timestamptz := timezone('utc', now());
  window_interval interval := (GREATEST(p_window_ms, 1)::text || ' milliseconds')::interval;
  current_count integer;
  current_reset_at timestamptz;
BEGIN
  IF p_bucket_key IS NULL OR btrim(p_bucket_key) = '' THEN
    RAISE EXCEPTION 'p_bucket_key is required';
  END IF;

  IF p_limit <= 0 THEN
    RAISE EXCEPTION 'p_limit must be positive';
  END IF;

  LOOP
    UPDATE public.request_rate_limits
    SET
      count = CASE
        WHEN request_rate_limits.reset_at <= now_ts THEN 1
        ELSE request_rate_limits.count + 1
      END,
      reset_at = CASE
        WHEN request_rate_limits.reset_at <= now_ts THEN now_ts + window_interval
        ELSE request_rate_limits.reset_at
      END,
      updated_at = now_ts
    WHERE request_rate_limits.bucket_key = p_bucket_key
    RETURNING request_rate_limits.count, request_rate_limits.reset_at
      INTO current_count, current_reset_at;

    EXIT WHEN FOUND;

    BEGIN
      INSERT INTO public.request_rate_limits (
        bucket_key,
        count,
        reset_at,
        created_at,
        updated_at
      )
      VALUES (
        p_bucket_key,
        1,
        now_ts + window_interval,
        now_ts,
        now_ts
      )
      RETURNING request_rate_limits.count, request_rate_limits.reset_at
        INTO current_count, current_reset_at;

      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        NULL;
    END;
  END LOOP;

  RETURN QUERY
  SELECT
    current_count <= p_limit,
    CASE
      WHEN current_count > p_limit THEN GREATEST(1, CEIL(EXTRACT(EPOCH FROM current_reset_at - now_ts))::integer)
      ELSE 0
    END,
    GREATEST(p_limit - LEAST(current_count, p_limit), 0),
    current_reset_at;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_request_rate_limit(text, integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_request_rate_limit(text, integer, integer)
  TO service_role;
