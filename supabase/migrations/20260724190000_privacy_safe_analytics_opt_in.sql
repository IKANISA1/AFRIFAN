-- Analytics consent is explicit opt-in. The prior schema defaulted this field
-- to true before the control was exposed in the supporter UI, so those values
-- are not treated as informed consent.
alter table public.user_privacy_settings
  alter column analytics_enabled set default false;

update public.user_privacy_settings
set analytics_enabled = false
where analytics_enabled is true;

comment on column public.user_privacy_settings.analytics_enabled is
  'Explicit opt-in consent for coarse, non-identifying product analytics. Defaults to false.';
