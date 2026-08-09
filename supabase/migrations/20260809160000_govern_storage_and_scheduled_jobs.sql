-- Bring production Storage delivery and pg_cron under migration control.
-- Retired mobility, BioPay and store-disabled multiplier jobs are deliberately
-- not recreated. Edge cron authentication is resolved from Vault at runtime;
-- no credential is embedded in migration history or cron.job.

do $extension_bootstrap$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    execute 'create extension pg_cron with schema pg_catalog';
  end if;
end
$extension_bootstrap$;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['application/x-africlub-retired-upload']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- New uploads use a separate bucket with no client-write policy. Public bucket
-- delivery keeps GET URLs public; all writes are performed by the governed
-- admin-upload-image Edge Function using the project secret key.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'africlub-product-images',
  'africlub-product-images',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $govern_cron$
declare
  v_job record;
begin
  for v_job in
    select jobid
    from cron.job
    where jobname in (
      'expire-mobility-trips',
      'redact-momo-sms-artifacts-daily',
      'check-momo-sms-migration-safety-daily',
      'purge_edge_function_rate_events',
      'expire_biopay_payment_intents',
      'settle-prediction-notifications',
      'daily-multiplier-refresh',
      'daily-fixture-sync'
    )
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;
end
$govern_cron$;

select cron.schedule(
  'redact-momo-sms-artifacts-daily',
  '17 2 * * *',
  $job$select public.redact_momo_sms_artifacts_due(
    interval '90 days', interval '30 days', 500
  );$job$
);

select cron.schedule(
  'check-momo-sms-migration-safety-daily',
  '29 2 * * *',
  $job$select public.run_momo_sms_migration_safety_check();$job$
);

select cron.schedule(
  'purge_edge_function_rate_events',
  '*/15 * * * *',
  $job$delete from public.edge_function_rate_events
    where created_at < now() - interval '24 hours';$job$
);

select cron.schedule(
  'settle-prediction-notifications',
  '*/5 * * * *',
  $job$
    select net.http_post(
      url := 'https://mmpbzcdhfvplxplnfucy.supabase.co/functions/v1/settle-prediction-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'africlub_cron_job_secret'
          limit 1
        )
      ),
      body := '{}'::jsonb
    ) as request_id;
  $job$
);

select cron.schedule(
  'daily-fixture-sync',
  '0 5 * * *',
  $job$
    select net.http_post(
      url := 'https://mmpbzcdhfvplxplnfucy.supabase.co/functions/v1/football-sync',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'africlub_cron_job_secret'
          limit 1
        )
      ),
      body := '{"command":"full-sync"}'::jsonb
    ) as request_id;
  $job$
);
