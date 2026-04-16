import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:feat_contributions/feat_contributions.dart';
import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:feat_gamification/feat_gamification.dart';
import 'package:feat_home/feat_home.dart';
import 'package:feat_live/feat_live.dart';
import 'package:feat_membership/feat_membership.dart';
import 'package:feat_onboarding/feat_onboarding.dart';
import 'package:feat_settings/feat_settings.dart';
import 'package:feat_shop/feat_shop.dart';
import 'package:feat_ticketing/feat_ticketing.dart';

/// Shared registry for all feature modules used by AFRICLUB apps.
abstract final class AppModuleRegistry {
  static List<FeatureModule> build(ClubConfig config) {
    return _allModules
        .where((module) => module.isEnabled(config.features))
        .toList(growable: false);
  }

  static final List<FeatureModule> _allModules = <FeatureModule>[
    HomeModule(),
    LiveModule(),
    FanzoneModule(),
    ChallengeModule(),
    BioPayModule(),
    SettingsModule(),
    OnboardingModule(),
    MembershipModule(),
    ContributionsModule(),
    TicketingModule(),
    FanClubsModule(),
    AdminModule(),
    ShopModule(),
  ];
}
