-- Improve prediction settlement notifications so they deep-link into
-- the relevant match detail instead of a generic predictions hub.

create or replace function public.prediction_queue_settlement_notifications(
  p_fixture_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_notif_count integer := 0;
  v_user record;
  v_fixture record;
  v_title text;
  v_body text;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  select
    f.id,
    ht.name as home_team,
    at.name as away_team,
    f.home_score,
    f.away_score
  into v_fixture
  from football.fixtures f
  join football.teams ht on ht.id = f.home_team_id
  join football.teams at on at.id = f.away_team_id
  where f.id = p_fixture_id;

  if v_fixture is null then
    return jsonb_build_object('status', 'error', 'message', 'Fixture not found.');
  end if;

  for v_user in
    select
      p.user_id,
      count(*) filter (where p.status = 'won') as won_count,
      count(*) filter (where p.status = 'lost') as lost_count,
      coalesce(sum(p.fet_earned) filter (where p.status = 'won'), 0) as total_earned
    from football.predictions p
    where p.fixture_id = p_fixture_id
      and p.status in ('won', 'lost')
    group by p.user_id
  loop
    if v_user.won_count > 0 and v_user.lost_count = 0 then
      v_title := '🎉 All predictions correct!';
      v_body := format('%s vs %s — You earned +%s FET!',
        v_fixture.home_team, v_fixture.away_team, v_user.total_earned);
    elsif v_user.won_count > 0 then
      v_title := format('⚽ %s/%s predictions correct',
        v_user.won_count, v_user.won_count + v_user.lost_count);
      v_body := format('%s vs %s — You earned +%s FET.',
        v_fixture.home_team, v_fixture.away_team, v_user.total_earned);
    else
      v_title := '⚽ Results are in';
      v_body := format('%s vs %s — Better luck next time!',
        v_fixture.home_team, v_fixture.away_team);
    end if;

    insert into football.prediction_notifications (
      user_id, notification_type, title, body, payload
    )
    values (
      v_user.user_id,
      'settlement',
      v_title,
      v_body,
      jsonb_build_object(
        'fixture_id', p_fixture_id,
        'won', v_user.won_count,
        'lost', v_user.lost_count,
        'earned', v_user.total_earned,
        'route', '/predictions/match/' || p_fixture_id::text
      )
    );

    v_notif_count := v_notif_count + 1;
  end loop;

  return jsonb_build_object(
    'status', 'ok',
    'notifications_queued', v_notif_count
  );
end;
$$;

grant execute on function public.prediction_queue_settlement_notifications(uuid) to service_role;
