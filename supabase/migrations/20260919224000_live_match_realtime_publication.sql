begin;

-- Publish only the two already-readable backing tables. The public joined view
-- is fetched by the client after each event; channel names are not access gates.
do $$
begin
  if not exists (select 1 from pg_publication where pubname='supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if exists(select 1 from pg_publication where pubname='supabase_realtime' and puballtables) then
    raise exception 'REALTIME_ALL_TABLES_REQUIRES_REVIEW';
  end if;
  if not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='matches') then
    alter publication supabase_realtime add table public.matches;
  end if;
  if not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='football' and tablename='fixtures') then
    alter publication supabase_realtime add table football.fixtures;
  end if;
end;
$$;

commit;
