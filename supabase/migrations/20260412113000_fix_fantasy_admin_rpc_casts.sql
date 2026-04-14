create or replace function public.fantasy_admin_club_competitions(
  p_club_id bigint
) returns table(
  id uuid,
  slug text,
  name text,
  short_name text,
  season text,
  description text,
  competition_type text,
  status text,
  primary_color text,
  logo_url text,
  country_code text,
  provider text,
  external_league_id integer,
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  promo_title text,
  promo_body text,
  badge_label text,
  cta_label text,
  hero_image_url text,
  sort_order integer,
  is_visible boolean,
  is_featured boolean,
  is_playable boolean,
  entry_window_opens_at timestamp with time zone,
  entry_window_closes_at timestamp with time zone,
  active_entries bigint
)
language plpgsql
stable
security definer
set search_path to 'public', 'fantasy'
as $$
begin
  if not (public.is_super_admin() or public.is_club_admin(p_club_id) or public.is_admin_user()) then
    raise exception 'Admin privileges required';
  end if;

  return query
  with entry_counts as (
    select fe.competition_id, count(*)::bigint as active_entries
    from fantasy.fantasy_entries fe
    group by fe.competition_id
  )
  select
    c.id,
    c.slug,
    c.name,
    c.short_name,
    c.season,
    c.description,
    c.competition_type::text,
    c.status::text,
    c.primary_color,
    c.logo_url,
    c.country_code,
    c.provider::text,
    c.external_league_id,
    c.start_date,
    c.end_date,
    e.promo_title,
    e.promo_body,
    e.badge_label,
    e.cta_label,
    e.hero_image_url,
    e.sort_order,
    e.is_visible,
    e.is_featured,
    e.is_playable,
    e.entry_window_opens_at,
    e.entry_window_closes_at,
    coalesce(ec.active_entries, 0) as active_entries
  from fantasy.competitions c
  left join public.fantasy_competition_enablements e
    on e.competition_id = c.id
   and e.club_id = p_club_id
  left join entry_counts ec
    on ec.competition_id = c.id
  order by c.start_date asc, c.created_at asc;
end;
$$;
