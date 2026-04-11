alter table fantasy.player_gameweek_stats replica identity full;
alter table fantasy.entry_gameweek_scores replica identity full;
alter table fantasy.gameweeks replica identity full;
alter table fantasy.fantasy_entries replica identity full;

do $$
begin
  alter publication supabase_realtime add table fantasy.player_gameweek_stats;
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table fantasy.entry_gameweek_scores;
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table fantasy.gameweeks;
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table fantasy.fantasy_entries;
exception
  when duplicate_object then null;
end;
$$;
