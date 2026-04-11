ALTER TABLE public.user_privacy_settings
ADD COLUMN IF NOT EXISTS momo_sms_autoread_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.user_privacy_settings.momo_sms_autoread_enabled IS
'Explicit in-app consent for Android Mobile Money SMS autoread. Must remain opt-in.';
