-- Keep Predict as the only supported prediction experience. Historical ledger
-- records remain private; this migration never grants new rollout approvals.
begin;

-- Do not strand outstanding stakes or entries while retiring the old products.
do $$ begin
  if exists (select 1 from football.jackpot_entry_predictions where status='pending')
    or exists (select 1 from football.prediction_friend_challenges where status in ('pending','accepted')) then
    raise exception 'Resolve outstanding retired prediction entries before applying Predict-only retirement';
  end if;
end $$;

-- Preserve content ownership without reviving removed feature flags.
update public.platform_content_blocks block
set feature_id = (
  select current_feature.id from public.platform_features current_feature
  where current_feature.feature_key = 'predict'
    and current_feature.club_id is not distinct from old_feature.club_id
  limit 1
)
from public.platform_features old_feature
where block.feature_id=old_feature.id and old_feature.feature_key in ('fanzone','challenge');

update public.platform_feature_rules
set dependency_rules = jsonb_set(dependency_rules, '{requires}',
  coalesce((select jsonb_agg(value) from jsonb_array_elements(dependency_rules->'requires')
    where value not in ('"fanzone"'::jsonb, '"challenge"'::jsonb)), '[]'::jsonb)), updated_at=now()
where jsonb_typeof(dependency_rules->'requires')='array'
  and (dependency_rules->'requires' ?| array['fanzone','challenge']);

delete from public.platform_features where feature_key in ('fanzone','challenge');
delete from public.platform_route_registry
where feature_key in ('fanzone','challenge')
  or path_pattern ~ '^/(fanzone|challenge)(/|$)';
delete from public.platform_feature_channels where route_key ~ '^/?(fanzone|challenge)(/|$)';
delete from public.site_navigation_items where feature_key in ('fanzone','challenge') or href ~ '^/(fanzone|challenge)(/|\?|$)';
delete from public.site_search_items where feature_key in ('fanzone','challenge') or href ~ '^/(fanzone|challenge)(/|\?|$)';
delete from public.platform_option_values where option_set_id in
  (select id from public.platform_option_sets where option_set_key='challenge_stake_fet');
delete from public.platform_option_sets where option_set_key='challenge_stake_fet';

-- Rewrite only persisted discovery links with supported equivalents. There are
-- deliberately no client redirects or route aliases for the removed URLs.
update public.quick_actions set route=case
  when route ~ '^/fanzone/(my|notifications)(/|\?|$)' then '/predict?section=history'
  when route ~ '^/fanzone/(wallet|offers|rewards|history|badges|streak)(/|\?|$)' then '/predict?section=wallet'
  when route ~ '^/fanzone/(fixtures|live|league|standings|team|leaderboard)(/|\?|$)' then '/club/fixtures'
  else '/predict' end,
  title=case when action_key in ('predict','fan_zone') then 'Predict' else title end,
  action_key=case when action_key='fan_zone' then 'predict' else action_key end
where route ~ '^/(fanzone|challenge)(/|\?|$)';

-- Preserve historical redemptions while removing unsupported rewards from sale.
update public.fet_reward_store_items set is_active=false where slug='jackpot-extra-entry';
update public.fet_reward_store_items set reward=replace(reward,'FANZONE','Predict'), slug='predict-premium-badge'
where slug='fanzone-premium-badge';

-- Remove obsolete entry RPCs and settlement hooks; current predict_* and
-- partner-pool operations retain their existing authorization contracts.
drop trigger if exists prediction_settlements_refresh_jackpot on football.prediction_settlements;
do $$ declare fn record; definition text; begin
  for fn in select oid from pg_proc where pronamespace='public'::regnamespace
    and prokind='f' and prosrc like '%perform public.prediction_settle_friend_challenges(p_fixture_id);%'
  loop
    definition := pg_get_functiondef(fn.oid);
    execute replace(definition, 'perform public.prediction_settle_friend_challenges(p_fixture_id);', '');
  end loop;
  for fn in select oid::regprocedure as signature from pg_proc
    where pronamespace='public'::regnamespace and prokind='f'
      and (proname ~ '^prediction_.*(jackpot|friend_challenge)'
        or proname in ('prediction_place','prediction_place_acca'))
  loop execute format('drop function %s', fn.signature); end loop;
end $$;

create schema if not exists retired;
revoke all on schema retired from public, anon, authenticated, service_role;
alter table football.jackpot_entry_predictions set schema retired;
alter table football.jackpot_round_legs set schema retired;
alter table football.jackpot_rounds set schema retired;
alter table football.prediction_friend_challenges set schema retired;
revoke all on all tables in schema retired from public, anon, authenticated, service_role;

notify pgrst, 'reload schema';
commit;
