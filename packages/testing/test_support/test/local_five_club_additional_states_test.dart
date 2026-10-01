import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import '../../../features/feat_admin/test/predict_ops_screen_test.dart'
    as suite6;
import '../../../features/feat_contributions/test/contributions_hub_screen_test.dart'
    as suite7;
import '../../../features/feat_fan_clubs/test/fan_clubs_list_screen_test.dart'
    as suite2;
import '../../../features/feat_gamification/test/predict_screen_test.dart'
    as suite3;
import '../../../features/feat_home/test/discovery_search_test.dart' as suite5;
import '../../../features/feat_membership/test/membership_screen_ui_test.dart'
    as suite1;
import '../../../features/feat_membership/test/tier_detail_screen_states_test.dart'
    as suite0;
import '../../../features/feat_ticketing/test/match_list_ui_test.dart'
    as suite4;
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
      group('feat_membership/tier_detail_screen_states_test.dart', suite0.main);
      group('feat_membership/membership_screen_ui_test.dart', suite1.main);
      group(
        'feat_fan_clubs/fan_clubs_list_screen_test.dart',
        () => suite2.main(localStateCoverage: true),
      );
      group('feat_gamification/predict_screen_test.dart', suite3.main);
      group(
        'feat_ticketing/match_list_ui_test.dart',
        () => suite4.main(localStateCoverage: true),
      );
      group('feat_home/discovery_search_test.dart', suite5.main);
      group(
        'feat_admin/predict_ops_screen_test.dart',
        () => suite6.main(localStateCoverage: true),
      );
      group(
        'feat_contributions/contributions_hub_screen_test.dart',
        () => suite7.main(localStateCoverage: true),
      );
    });
  }
}
