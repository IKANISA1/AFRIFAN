create or replace function public.fantasy_get_competition_context(
  p_competition_slug text
) returns table (
  competition_id uuid,
  competition_slug text,
  competition_name text,
  competition_type text,
  competition_status text,
  squad_config jsonb,
  transfer_config jsonb,
  gameweek_id uuid,
  gameweek_number integer,
  gameweek_name text,
  gameweek_status text,
  gameweek_deadline_at timestamptz,
  entry_id uuid,
  team_name text,
  bank_balance integer,
  team_value integer,
  overall_points integer,
  overall_rank integer
)
language sql
security definer
set search_path = public, fantasy
as $$
  with competition as (
    select
      c.id,
      c.slug,
      c.name,
      c.competition_type::text as competition_type,
      c.status::text as competition_status,
      c.squad_config,
      c.transfer_config
    from fantasy.competitions c
    where c.slug = p_competition_slug
  ),
  current_gameweek as (
    select
      gw.id,
      gw.number,
      gw.name,
      gw.status::text as status,
      gw.deadline_at
    from fantasy.gameweeks gw
    join competition c
      on c.id = gw.competition_id
    order by
      case gw.status
        when 'live' then 0
        when 'scoring' then 1
        when 'upcoming' then 2
        else 3
      end,
      gw.number asc
    limit 1
  ),
  manager_entry as (
    select
      fe.id,
      fe.team_name,
      fe.bank_balance,
      fe.team_value,
      fe.overall_points,
      fe.overall_rank
    from fantasy.fantasy_entries fe
    join competition c
      on c.id = fe.competition_id
    where fe.user_id = auth.uid()
    limit 1
  )
  select
    c.id as competition_id,
    c.slug as competition_slug,
    c.name as competition_name,
    c.competition_type,
    c.competition_status,
    c.squad_config,
    c.transfer_config,
    gw.id as gameweek_id,
    gw.number as gameweek_number,
    gw.name as gameweek_name,
    gw.status as gameweek_status,
    gw.deadline_at as gameweek_deadline_at,
    fe.id as entry_id,
    fe.team_name,
    fe.bank_balance,
    fe.team_value,
    fe.overall_points,
    fe.overall_rank
  from competition c
  left join current_gameweek gw
    on true
  left join manager_entry fe
    on true;
$$;

create or replace function public.fantasy_get_player_pool(
  p_competition_slug text
) returns table (
  player_id integer,
  name text,
  short_name text,
  photo_url text,
  player_position text,
  team_id integer,
  team_name text,
  team_short text,
  team_logo_url text,
  nationality text,
  price integer,
  price_change integer,
  ownership_percent numeric
)
language sql
security definer
set search_path = public, fantasy
as $$
  select
    p.external_id as player_id,
    p.name,
    p.short_name,
    p.photo_url,
    p.position::text as player_position,
    p.team_id,
    p.team_name,
    p.team_short,
    p.team_logo_url,
    p.nationality,
    pr.price,
    pr.price_change,
    pr.ownership_percent
  from fantasy.competitions c
  join fantasy.player_competition_prices pr
    on pr.competition_id = c.id
  join fantasy.players p
    on p.external_id = pr.player_id
  where c.slug = p_competition_slug
  order by
    case p.position
      when 'GK' then 0
      when 'DEF' then 1
      when 'MID' then 2
      else 3
    end,
    pr.price desc,
    p.team_name asc,
    p.name asc;
$$;

create or replace function public.fantasy_get_squad(
  p_entry_id uuid,
  p_gameweek_id uuid default null
) returns table (
  selection_id uuid,
  gameweek_id uuid,
  player_id integer,
  name text,
  short_name text,
  photo_url text,
  player_position text,
  team_name text,
  team_short text,
  team_logo_url text,
  purchase_price integer,
  is_starter boolean,
  bench_order integer,
  is_captain boolean,
  is_vice_captain boolean,
  multiplier integer
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_gameweek_id uuid := p_gameweek_id;
begin
  perform fantasy.assert_entry_owner(p_entry_id);

  if v_gameweek_id is null then
    select gw.id
    into v_gameweek_id
    from fantasy.gameweeks gw
    join fantasy.fantasy_entries fe
      on fe.competition_id = gw.competition_id
    where fe.id = p_entry_id
    order by
      case gw.status
        when 'live' then 0
        when 'scoring' then 1
        when 'upcoming' then 2
        else 3
      end,
      gw.number asc
    limit 1;
  end if;

  if v_gameweek_id is null then
    return;
  end if;

  return query
  select
    ss.id as selection_id,
    ss.gameweek_id,
    ss.player_id,
    p.name,
    p.short_name,
    p.photo_url,
    p.position::text as player_position,
    p.team_name,
    p.team_short,
    p.team_logo_url,
    ss.purchase_price,
    ss.is_starter,
    ss.bench_order,
    ss.is_captain,
    ss.is_vice_captain,
    ss.multiplier
  from fantasy.squad_selections ss
  join fantasy.players p
    on p.external_id = ss.player_id
  where ss.entry_id = p_entry_id
    and ss.gameweek_id = v_gameweek_id
  order by
    ss.is_starter desc,
    case p.position
      when 'GK' then 0
      when 'DEF' then 1
      when 'MID' then 2
      else 3
    end,
    ss.bench_order asc nulls last,
    p.name asc;
end;
$$;

grant execute on function public.fantasy_get_competition_context(text) to anon, authenticated, service_role;
grant execute on function public.fantasy_get_player_pool(text) to anon, authenticated, service_role;
grant execute on function public.fantasy_get_squad(uuid, uuid) to authenticated, service_role;
