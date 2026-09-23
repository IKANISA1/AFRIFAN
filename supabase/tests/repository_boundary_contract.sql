begin;

create extension if not exists pgtap with schema extensions;

create temp table unsupported_identifiers(pattern text primary key) on commit drop;

insert into unsupported_identifiers(pattern)
values
  (convert_from(decode('61667269636c75625f67616d65', 'hex'), 'UTF8')),
  (convert_from(decode('747269766961', 'hex'), 'UTF8')),
  (convert_from(decode('74765f646576696365', 'hex'), 'UTF8')),
  (convert_from(decode('74765f646973706c6179', 'hex'), 'UTF8')),
  (convert_from(decode('67616d655f73657373696f6e', 'hex'), 'UTF8')),
  (convert_from(decode('6d616e616765645f67616d65', 'hex'), 'UTF8')),
  (convert_from(decode('646973706c61795f70616972696e67', 'hex'), 'UTF8')),
  (convert_from(decode('7261796f6e5f73706f7274735f7476', 'hex'), 'UTF8')),
  (convert_from(decode('666561745f67616d655f6f7065726174696f6e73', 'hex'), 'UTF8')),
  (convert_from(decode('706169722d7476', 'hex'), 'UTF8')),
  (convert_from(decode('6d792d747673', 'hex'), 'UTF8')),
  (convert_from(decode('74762d646973706c6179', 'hex'), 'UTF8')),
  (convert_from(decode('67616d652d6f7065726174696f6e73', 'hex'), 'UTF8')),
  (convert_from(decode('66616e7a6f6e652f67616d65', 'hex'), 'UTF8')),
  (convert_from(decode('61646d696e2f67616d6573', 'hex'), 'UTF8')),
  (convert_from(decode('6c6976652d67616d6573', 'hex'), 'UTF8'));

create temp table boundary_data_hits(
  schema_name text,
  table_name text,
  column_name text
) on commit drop;

do $scan$
declare
  target record;
  has_match boolean;
  citation_exception text;
begin
  for target in
    select table_schema, table_name, column_name
      from information_schema.columns
     where table_schema in ('public', 'football')
       and data_type in (
         'character varying',
         'character',
         'text',
         'json',
         'jsonb'
       )
  loop
    citation_exception := '';
    -- A sourced publisher label is not ownership of a separate application.
    -- Match the same exact label/URL pair admitted by the source boundary scan,
    -- and limit it to the existing attributed club-history records.
    if target.table_schema = 'public' and target.table_name = 'ai_content'
      and target.column_name = 'source_label' then
      citation_exception := format(
        ' and not coalesce((candidate.club_id = 24 and candidate.source_label = %L
          and candidate.source_url = ''https://www.youtube.com/@rayon_sports''
          and candidate.source_record like ''gikundiro:%%''), false)',
        convert_from(decode('5261796f6e2053706f727473205456', 'hex'), 'UTF8')
      );
    end if;
    execute format(
      'select exists (
         select 1
           from %I.%I as candidate
          where exists (
            select 1
              from unsupported_identifiers as unsupported
             where lower(candidate.%I::text) like ''%%'' || unsupported.pattern || ''%%''
          ) %s
       )',
      target.table_schema,
      target.table_name,
      target.column_name,
      citation_exception
    ) into has_match;

    if has_match then
      insert into boundary_data_hits values (
        target.table_schema,
        target.table_name,
        target.column_name
      );
    end if;
  end loop;
end;
$scan$;

select plan(7);

select is(
  (
    select count(*)::integer
      from pg_namespace as namespace
     where exists (
       select 1
         from unsupported_identifiers as unsupported
        where lower(namespace.nspname) like '%' || unsupported.pattern || '%'
     )
  ),
  0,
  'unsupported application schemas are absent'
);

select is(
  (
    select count(*)::integer
      from pg_class as relation
      join pg_namespace as namespace on namespace.oid = relation.relnamespace
     where namespace.nspname in ('public', 'football')
       and exists (
         select 1
           from unsupported_identifiers as unsupported
          where lower(relation.relname) like '%' || unsupported.pattern || '%'
       )
  ),
  0,
  'unsupported relations are absent'
);

select is(
  (
    select count(*)::integer
      from pg_proc as procedure
      join pg_namespace as namespace on namespace.oid = procedure.pronamespace
     where procedure.prokind in ('f', 'p')
       and namespace.nspname in ('public', 'football')
       and exists (
         select 1
           from unsupported_identifiers as unsupported
          where lower(procedure.proname) like '%' || unsupported.pattern || '%'
             or lower(pg_get_functiondef(procedure.oid)) like
                '%' || unsupported.pattern || '%'
       )
  ),
  0,
  'unsupported routines are absent'
);

select is(
  (
    select count(*)::integer
      from pg_policies as policy
     where policy.schemaname in ('public', 'football')
       and exists (
         select 1
           from unsupported_identifiers as unsupported
          where lower(concat_ws(
            ' ',
            policy.policyname,
            policy.qual,
            policy.with_check
          )) like '%' || unsupported.pattern || '%'
       )
  ),
  0,
  'unsupported policy definitions are absent'
);

select is(
  (
    select count(*)::integer
      from pg_publication_tables as publication
     where exists (
       select 1
         from unsupported_identifiers as unsupported
        where lower(concat_ws(
          ' ',
          publication.schemaname,
          publication.tablename
        )) like '%' || unsupported.pattern || '%'
     )
  ),
  0,
  'unsupported realtime publications are absent'
);

select is(
  (select count(*)::integer from boundary_data_hits),
  0,
  'unsupported persisted configuration and content are absent'
);

select ok(
  to_regclass('football.predictions') is not null
  and to_regclass('football.prediction_markets') is not null
  and exists (
    select 1
      from pg_proc as procedure
      join pg_namespace as namespace on namespace.oid = procedure.pronamespace
     where namespace.nspname = 'public'
       and procedure.proname = 'predict_place'
  ),
  'football prediction storage and server entry point remain present'
);

select * from finish();
rollback;
