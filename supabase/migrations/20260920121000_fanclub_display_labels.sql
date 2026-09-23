-- Standardize public and operator copy while preserving stable API identifiers.
begin;
do $$ declare field record; begin
 for field in select table_name,column_name from information_schema.columns
 where table_schema='public'
   and table_name in ('fan_clubs','site_navigation_items','site_search_items','admin_dashboard_actions','platform_features','quick_actions')
   and column_name in ('name','title','subtitle','description','label','display_name','search_text','eyebrow')
   and data_type='text'
 loop
   execute format('update public.%I set %I=regexp_replace(%I, %L, %L, %L) where %I ~* %L',
     field.table_name,field.column_name,field.column_name,'\mchapters?\M','FanClubs','gi',field.column_name,'\mchapters?\M');
 end loop;
end $$;
commit;
