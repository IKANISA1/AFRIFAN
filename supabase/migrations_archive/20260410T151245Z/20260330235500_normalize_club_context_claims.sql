-- Normalize slug-style club identifiers into bigint-backed club ids in JWT
-- access paths so RLS and BioPay server-side lookups behave consistently.

CREATE OR REPLACE FUNCTION public.requesting_club_id()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    public.normalize_club_id(
      NULLIF(
        COALESCE(
          current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
          current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id',
          current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'club_id'
        ),
        ''
      )
    )::text,
    (
      SELECT p.club_id::text
      FROM public.profiles p
      WHERE p.id = auth.uid()
      LIMIT 1
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  claims                jsonb;
  app_meta              jsonb;
  user_meta             jsonb;
  v_raw_club_id         text;
  v_normalized_club_id  text;
  v_user_role           text;
BEGIN
  claims := event -> 'claims';
  app_meta := claims -> 'app_metadata';
  user_meta := claims -> 'user_metadata';

  v_raw_club_id := COALESCE(
    app_meta ->> 'club_id',
    user_meta ->> 'club_id',
    ''
  );
  v_normalized_club_id := COALESCE(
    public.normalize_club_id(NULLIF(v_raw_club_id, ''))::text,
    v_raw_club_id
  );
  v_user_role := COALESCE(app_meta ->> 'role', 'fan');

  claims := jsonb_set(claims, '{club_id}', to_jsonb(v_normalized_club_id));
  claims := jsonb_set(claims, '{role}', to_jsonb(v_user_role));
  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;
