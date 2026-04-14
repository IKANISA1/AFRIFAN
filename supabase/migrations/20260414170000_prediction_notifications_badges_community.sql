-- ============================================================================
-- Phase 4: FCM settlement notifications + friend comparison view
-- Adds push notification queueing for prediction settlements
-- and a friend predictions comparison view.
-- ============================================================================

-- ── Prediction notification queue ─────────────────────────────────────────
-- Service role inserts notification payloads after settlement.
-- A Supabase Edge Function or cron picks them up and sends via FCM.

create table if not exists football.prediction_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null default 'settlement',
  title text not null,
  body text not null,
  payload jsonb not null default '{}',
  is_sent boolean not null default false,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_pred_notif_user_unsent
  on football.prediction_notifications (user_id, is_sent)
  where is_sent = false;

alter table football.prediction_notifications enable row level security;

create policy "Users read own notifications"
  on football.prediction_notifications for select
  using (auth.uid() = user_id);

create policy "Service role manages notifications"
  on football.prediction_notifications for all
  to service_role
  using (true)
  with check (true);

-- ── Queue settlement notifications ────────────────────────────────────────
-- Called by service_role after prediction_settle_fixture.
-- Generates one notification per user who had predictions on this fixture.

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

  -- Get fixture info
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

  -- For each user who had settled predictions on this fixture
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
    -- Build notification text
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

    -- Insert notification
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
        'route', '/predictions/my'
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

-- ── Send pending notifications via FCM ────────────────────────────────────
-- Processes the queue: reads user_fcm_tokens, builds FCM payloads.
-- Designed to be called by a Supabase Edge Function on a cron.

create or replace function public.prediction_get_pending_notifications(
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_results jsonb := '[]'::jsonb;
  v_notif record;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  for v_notif in
    select
      pn.id,
      pn.user_id,
      pn.title,
      pn.body,
      pn.payload,
      array_agg(t.token) filter (where t.token is not null) as fcm_tokens
    from football.prediction_notifications pn
    left join public.user_fcm_tokens t on t.user_id = pn.user_id
    where pn.is_sent = false
    group by pn.id, pn.user_id, pn.title, pn.body, pn.payload
    order by pn.created_at asc
    limit p_limit
  loop
    v_results := v_results || jsonb_build_object(
      'id', v_notif.id,
      'user_id', v_notif.user_id,
      'title', v_notif.title,
      'body', v_notif.body,
      'payload', v_notif.payload,
      'fcm_tokens', to_jsonb(coalesce(v_notif.fcm_tokens, '{}'))
    );
  end loop;

  return jsonb_build_object(
    'status', 'ok',
    'notifications', v_results
  );
end;
$$;

grant execute on function public.prediction_get_pending_notifications(integer) to service_role;

-- ── Mark notifications as sent ────────────────────────────────────────────

create or replace function public.prediction_mark_notifications_sent(
  p_notification_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_count integer;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  update football.prediction_notifications
  set is_sent = true, sent_at = now()
  where id = any(p_notification_ids)
    and is_sent = false;

  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'status', 'ok',
    'marked_sent', v_count
  );
end;
$$;

grant execute on function public.prediction_mark_notifications_sent(uuid[]) to service_role;

-- ── Friend predictions comparison view ────────────────────────────────────
-- Shows predictions from other users on the same fixture/market,
-- useful for "see how your friends predicted" feature.
-- Security: only shows non-PII (public user alias + outcome).

create or replace view public.prediction_fixture_community
with (security_invoker = true) as
select
  p.fixture_id,
  p.fixture_market_id,
  pm.name as market_name,
  pm.short_name as market_short_name,
  p.selected_outcome,
  count(*) as pick_count,
  round(
    count(*)::numeric / nullif(sum(count(*)) over (partition by p.fixture_market_id), 0) * 100,
    1
  ) as pick_percentage
from football.predictions p
join football.fixture_markets fm on fm.id = p.fixture_market_id
join football.prediction_markets pm on pm.id = fm.market_id
where p.status != 'cancelled'
group by p.fixture_id, p.fixture_market_id, pm.name, pm.short_name, p.selected_outcome;

grant select on public.prediction_fixture_community to anon, authenticated;

-- ── Prediction badges table ───────────────────────────────────────────────
-- Tracks which milestone badges a user has earned.

create table if not exists football.prediction_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_slug text not null,
  badge_name text not null,
  badge_description text not null default '',
  threshold_wins integer not null,
  earned_at timestamptz not null default now(),
  unique (user_id, badge_slug)
);

alter table football.prediction_badges enable row level security;

create policy "Users read own badges"
  on football.prediction_badges for select
  using (auth.uid() = user_id);

create policy "Service role manages badges"
  on football.prediction_badges for all
  to service_role
  using (true)
  with check (true);

-- ── Award badge (idempotent) ──────────────────────────────────────────────

create or replace function public.prediction_award_badge(
  p_user_id uuid,
  p_badge_slug text,
  p_badge_name text,
  p_description text,
  p_threshold integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  insert into football.prediction_badges (
    user_id, badge_slug, badge_name, badge_description, threshold_wins
  )
  values (p_user_id, p_badge_slug, p_badge_name, p_description, p_threshold)
  on conflict (user_id, badge_slug) do nothing;

  return jsonb_build_object(
    'status', 'ok',
    'badge', p_badge_slug,
    'awarded', true
  );
end;
$$;

grant execute on function public.prediction_award_badge(uuid, text, text, text, integer) to service_role;

-- ── User's earned prediction badges ───────────────────────────────────────

create or replace function public.prediction_get_user_badges(
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_target uuid := coalesce(p_user_id, auth.uid());
  v_badges jsonb;
begin
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'badge_slug', pb.badge_slug,
      'badge_name', pb.badge_name,
      'badge_description', pb.badge_description,
      'threshold_wins', pb.threshold_wins,
      'earned_at', pb.earned_at
    ) order by pb.threshold_wins
  ), '[]'::jsonb)
  into v_badges
  from football.prediction_badges pb
  where pb.user_id = v_target;

  return v_badges;
end;
$$;

grant execute on function public.prediction_get_user_badges(uuid) to authenticated;
