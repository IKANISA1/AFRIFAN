begin;

select plan(17);

select is(
  (select public from storage.buckets where id = 'africlub-product-images'),
  true,
  'africlub-product-images is a public delivery bucket'
);
select is(
  (select file_size_limit from storage.buckets where id = 'africlub-product-images'),
  5242880::bigint,
  'africlub-product-images enforces a 5 MiB object limit'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'africlub-product-images'),
  array['image/png', 'image/jpeg', 'image/webp']::text[],
  'africlub-product-images allows only governed image MIME types'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'product-images'),
  array['application/x-africlub-retired-upload']::text[],
  'legacy product-images accepts no supported upload MIME type'
);
select ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and coalesce(qual, '') || coalesce(with_check, '')
        like '%africlub-product-images%'
  ),
  'new image bucket has no direct client object policy'
);
select ok(
  (select public from storage.buckets where id = 'product-images'),
  'legacy image URLs remain publicly deliverable'
);
select ok(
  (select count(*) from storage.buckets where id in (
    'product-images', 'africlub-product-images'
  )) = 2,
  'legacy delivery and governed upload buckets both exist'
);

select is(
  (select count(*) from cron.job where jobname in (
    'expire-mobility-trips', 'expire_biopay_payment_intents',
    'daily-multiplier-refresh'
  )),
  0::bigint,
  'retired mobility, BioPay and multiplier jobs are absent'
);
select is(
  (select count(*) from cron.job where jobname in (
    'redact-momo-sms-artifacts-daily',
    'check-momo-sms-migration-safety-daily',
    'purge_edge_function_rate_events',
    'settle-prediction-notifications',
    'daily-fixture-sync'
  )),
  5::bigint,
  'exactly five governed production jobs are scheduled'
);
select is((select schedule from cron.job where jobname =
  'redact-momo-sms-artifacts-daily'), '17 2 * * *', 'redaction schedule is exact');
select is((select schedule from cron.job where jobname =
  'check-momo-sms-migration-safety-daily'), '29 2 * * *', 'safety schedule is exact');
select is((select schedule from cron.job where jobname =
  'purge_edge_function_rate_events'), '*/15 * * * *', 'rate-event purge schedule is exact');
select is((select schedule from cron.job where jobname =
  'settle-prediction-notifications'), '*/5 * * * *', 'settlement schedule is exact');
select is((select schedule from cron.job where jobname =
  'daily-fixture-sync'), '0 5 * * *', 'fixture sync schedule is exact');
select ok(
  (select command from cron.job where jobname = 'settle-prediction-notifications')
    like '%vault.decrypted_secrets%africlub_cron_job_secret%',
  'settlement job resolves its secret from Vault at runtime'
);
select ok(
  (select command from cron.job where jobname = 'daily-fixture-sync')
    like '%vault.decrypted_secrets%africlub_cron_job_secret%',
  'fixture sync resolves its secret from Vault at runtime'
);
select is(
  (select count(*) from cron.job
    where command ~ '(eyJ[A-Za-z0-9_-]{20,}|sb_secret_|service_role_key)'),
  0::bigint,
  'no scheduled job embeds an API key or JWT'
);

select * from finish();
rollback;
