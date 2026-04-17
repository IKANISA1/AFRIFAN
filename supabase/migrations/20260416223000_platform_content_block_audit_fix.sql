-- Ensure content block mutations are captured in platform_feature_audit_logs.
-- Older environments may still be missing the content-block branch in
-- log_feature_config_change() and the dedicated trigger on platform_content_blocks.

CREATE OR REPLACE FUNCTION public.log_feature_config_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_feature_id uuid;
  v_action text;
  v_before jsonb := '{}'::jsonb;
  v_after  jsonb := '{}'::jsonb;
BEGIN
  IF TG_TABLE_NAME = 'platform_features' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.id;
    ELSE
      v_feature_id := NEW.id;
    END IF;
  ELSIF TG_TABLE_NAME = 'platform_feature_channels' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.feature_id;
    ELSE
      v_feature_id := NEW.feature_id;
    END IF;
  ELSIF TG_TABLE_NAME = 'platform_feature_rules' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.feature_id;
    ELSE
      v_feature_id := NEW.feature_id;
    END IF;
  ELSIF TG_TABLE_NAME = 'platform_content_blocks' THEN
    IF TG_OP = 'DELETE' THEN
      v_feature_id := OLD.feature_id;
    ELSE
      v_feature_id := NEW.feature_id;
    END IF;
  END IF;

  v_action := lower(TG_OP) || '_' || TG_TABLE_NAME;

  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_before := to_jsonb(OLD);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_after := to_jsonb(NEW);
  END IF;

  INSERT INTO public.platform_feature_audit_logs (
    feature_id,
    action,
    changed_by,
    before_state,
    after_state
  ) VALUES (
    v_feature_id,
    v_action,
    auth.uid(),
    v_before,
    v_after
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_feature_audit_content_blocks
  ON public.platform_content_blocks;

CREATE TRIGGER trg_feature_audit_content_blocks
  AFTER INSERT OR UPDATE OR DELETE ON public.platform_content_blocks
  FOR EACH ROW EXECUTE FUNCTION public.log_feature_config_change();
