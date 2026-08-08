-- Analytics consent is explicit opt-in. New records default to disabled, while
-- existing choices are preserved so a migration never silently revokes or
-- manufactures consent. The application records only affirmative user action.
alter table public.user_privacy_settings
  alter column analytics_enabled set default false;

comment on column public.user_privacy_settings.analytics_enabled is
  'Explicit opt-in for privacy-safe first-party analytics. New rows default to disabled; existing choices are preserved and may be enabled only by an affirmative user action.';
