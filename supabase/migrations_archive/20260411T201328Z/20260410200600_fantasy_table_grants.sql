grant usage on schema fantasy to anon, authenticated, service_role;

grant select on fantasy.entry_gameweek_scores to anon, authenticated, service_role;

grant select, insert, update on fantasy.fantasy_entries to authenticated, service_role;
grant delete on fantasy.fantasy_entries to service_role;

grant select, insert, update, delete on fantasy.squad_selections to authenticated, service_role;

grant select, insert, update on fantasy.leagues to authenticated, service_role;
grant delete on fantasy.leagues to service_role;

grant select, insert on fantasy.league_memberships to authenticated, service_role;
grant update, delete on fantasy.league_memberships to service_role;

grant select, insert on fantasy.transfer_history to authenticated, service_role;
grant update, delete on fantasy.transfer_history to service_role;
