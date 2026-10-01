import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import '../../../features/feat_admin/test/admin_cms_states_test.dart' as suite1;
import '../../../features/feat_admin/test/admin_competitions_states_test.dart'
    as suite2;
import '../../../features/feat_admin/test/admin_contributions_states_test.dart'
    as suite3;
import '../../../features/feat_admin/test/admin_dashboard_states_test.dart'
    as suite0;
import '../../../features/feat_admin/test/admin_feature_detail_states_test.dart'
    as suite4;
import '../../../features/feat_admin/test/admin_features_states_test.dart'
    as suite5;
import '../../../features/feat_admin/test/admin_matches_states_test.dart'
    as suite6;
import '../../../features/feat_admin/test/admin_notifications_states_test.dart'
    as suite7;
import '../../../features/feat_club/test/club_route_state_goldens_test.dart'
    as suite25;
import '../../../features/feat_contributions/test/group_detail_screen_states_test.dart'
    as suite8;
import '../../../features/feat_contributions/test/statement_screen_states_test.dart'
    as suite9;
import '../../../features/feat_gamification/test/match_detail_screen_states_test.dart'
    as suite10;
import '../../../features/feat_gamification/test/prediction_detail_screen_states_test.dart'
    as suite11;
import '../../../features/feat_gamification/test/share_card_generator_screen_states_test.dart'
    as suite12;
import '../../../features/feat_home/test/home_screen_states_test.dart'
    as suite13;
import '../../../features/feat_onboarding/test/onboarding_screen_states_test.dart'
    as suite14;
import '../../../features/feat_onboarding/test/supporter_phone_auth_states_test.dart'
    as suite26;
import '../../../features/feat_settings/test/edit_profile_screen_states_test.dart'
    as suite15;
import '../../../features/feat_settings/test/notification_preferences_screen_states_test.dart'
    as suite16;
import '../../../features/feat_settings/test/privacy_settings_screen_states_test.dart'
    as suite17;
import '../../../features/feat_settings/test/settings_screen_states_test.dart'
    as suite18;
import '../../../features/feat_shop/test/cart_screen_states_test.dart'
    as suite19;
import '../../../features/feat_shop/test/product_detail_screen_states_test.dart'
    as suite20;
import '../../../features/feat_shop/test/shop_screen_states_test.dart'
    as suite21;
import '../../../features/feat_ticketing/test/e_ticket_screen_states_test.dart'
    as suite22;
import '../../../features/feat_ticketing/test/seat_map_screen_states_test.dart'
    as suite23;
import '../../../features/feat_ticketing/test/ticket_detail_screen_states_test.dart'
    as suite24;
import 'fixtures/five_club_configs.dart';
import 'fixtures/local_route_state_assertions.dart';

void main() {
  final workspace = resolveRouteInventoryWorkspace(Directory.current);
  for (final club in fiveClubFixtures(workspace).entries) {
    group('five club ${club.key}', () {
      setUp(() {
        localRouteFixtureConfig = club.value;
        localRouteFixtureClub = club.key;
      });
      tearDown(() {
        localRouteFixtureConfig = null;
        localRouteFixtureClub = null;
      });
      group('feat_admin/admin_dashboard_states_test.dart', suite0.main);
      group('feat_admin/admin_cms_states_test.dart', suite1.main);
      group('feat_admin/admin_competitions_states_test.dart', suite2.main);
      group('feat_admin/admin_contributions_states_test.dart', suite3.main);
      group('feat_admin/admin_feature_detail_states_test.dart', suite4.main);
      group('feat_admin/admin_features_states_test.dart', suite5.main);
      group('feat_admin/admin_matches_states_test.dart', suite6.main);
      group('feat_admin/admin_notifications_states_test.dart', suite7.main);
      group(
        'feat_contributions/group_detail_screen_states_test.dart',
        suite8.main,
      );
      group(
        'feat_contributions/statement_screen_states_test.dart',
        suite9.main,
      );
      group(
        'feat_gamification/match_detail_screen_states_test.dart',
        suite10.main,
      );
      group(
        'feat_gamification/prediction_detail_screen_states_test.dart',
        suite11.main,
      );
      group(
        'feat_gamification/share_card_generator_screen_states_test.dart',
        suite12.main,
      );
      group('feat_home/home_screen_states_test.dart', suite13.main);
      group(
        'feat_onboarding/onboarding_screen_states_test.dart',
        () => suite14.main(localStateCoverage: true),
      );
      group('feat_settings/edit_profile_screen_states_test.dart', suite15.main);
      group(
        'feat_settings/notification_preferences_screen_states_test.dart',
        suite16.main,
      );
      group(
        'feat_settings/privacy_settings_screen_states_test.dart',
        suite17.main,
      );
      group(
        'feat_settings/settings_screen_states_test.dart',
        () => suite18.main(localStateCoverage: true),
      );
      group(
        'feat_shop/cart_screen_states_test.dart',
        () => suite19.main(localStateCoverage: true),
      );
      group('feat_shop/product_detail_screen_states_test.dart', suite20.main);
      group('feat_shop/shop_screen_states_test.dart', suite21.main);
      group('feat_ticketing/e_ticket_screen_states_test.dart', suite22.main);
      group('feat_ticketing/seat_map_screen_states_test.dart', suite23.main);
      group(
        'feat_ticketing/ticket_detail_screen_states_test.dart',
        suite24.main,
      );
      group('feat_club/club_route_state_goldens_test.dart', suite25.main);
      group(
        'feat_onboarding/supporter_phone_auth_states_test.dart',
        suite26.main,
      );
    });
  }
}
