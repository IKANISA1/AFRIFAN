begin;

create extension if not exists pgtap with schema extensions;

select plan(5);

select has_schema(
  'africlub_game',
  'historical game schema remains available for controlled retention and export'
);

select ok(
  not has_schema_privilege('anon', 'africlub_game', 'usage')
  and not has_schema_privilege('authenticated', 'africlub_game', 'usage')
  and not has_schema_privilege('service_role', 'africlub_game', 'usage'),
  'retired schema is inaccessible to Data API roles'
);

select is(
  (
    select count(*)::integer
      from pg_class relation
      join pg_namespace namespace on namespace.oid = relation.relnamespace
     where namespace.nspname = 'africlub_game'
       and relation.relkind in ('r', 'p', 'v', 'm')
       and (
         has_table_privilege('anon', relation.oid, 'select')
         or has_table_privilege('authenticated', relation.oid, 'select')
         or has_table_privilege('service_role', relation.oid, 'select')
       )
  ),
  0,
  'no retired relation remains client-readable'
);

select is(
  (
    select count(*)::integer
      from pg_proc procedure
      join pg_namespace namespace on namespace.oid = procedure.pronamespace
     where (
       namespace.nspname = 'africlub_game'
       or (
         namespace.nspname = 'public'
         and procedure.prokind = 'f'
         and pg_get_functiondef(procedure.oid) ilike '%africlub_game%'
       )
     )
       and (
         has_function_privilege('anon', procedure.oid, 'execute')
         or has_function_privilege('authenticated', procedure.oid, 'execute')
         or has_function_privilege('service_role', procedure.oid, 'execute')
       )
  ),
  0,
  'no retired function or public wrapper remains executable by API roles'
);

select is(
  (
    select count(*)::integer
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'africlub_game'
  ),
  0,
  'retired tables are absent from the realtime publication'
);

select * from finish();
rollback;
