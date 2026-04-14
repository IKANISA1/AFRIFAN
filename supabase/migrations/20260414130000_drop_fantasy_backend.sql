-- Remove fantasy backend objects after client-side fantasy feature deletion.
-- Keep the generic football catalog intact for predictions and other non-fantasy
-- football experiences.

do $$
declare
  routine_name text;
  relation record;
  relation_type text;
begin
  for routine_name in
    select p.oid::regprocedure::text
    from pg_proc p
    join pg_namespace n
      on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'fantasy\_%' escape '\'
  loop
    execute format('drop routine if exists %s cascade', routine_name);
  end loop;

  for relation in
    select c.relkind, c.relname
    from pg_class c
    join pg_namespace n
      on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname like 'fantasy\_%' escape '\'
      and c.relkind in ('r', 'p', 'v', 'm', 'S', 'f')
  loop
    relation_type :=
      case relation.relkind
        when 'r' then 'table'
        when 'p' then 'table'
        when 'v' then 'view'
        when 'm' then 'materialized view'
        when 'S' then 'sequence'
        when 'f' then 'foreign table'
      end;

    execute format(
      'drop %s if exists public.%I cascade',
      relation_type,
      relation.relname
    );
  end loop;
end
$$;

drop schema if exists fantasy cascade;
