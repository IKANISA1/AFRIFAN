import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
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
  /// Build the active module list for this app configuration.
  ///
  /// When [configSnapshot] (the raw JSON from `get_platform_config`) is
  /// provided, modules use [FeatureModule.isEnabledForConfig] which
  /// checks the admin-controlled platform feature registry first,
  /// falling back to [ClubConfig.features] when a feature is not found.
  ///
  /// When [configSnapshot] is null (network failed, first run, etc.),
  /// modules fall back to the compile-time [config.features] map.
  static List<FeatureModule> build(
    ClubConfig config, {
    Map<String, dynamic>? configSnapshot,
  }) {
    return _allModules.where((module) {
      if (configSnapshot != null) {
        return module.isEnabledForConfig(
          featureFlags: config.features,
          configSnapshot: configSnapshot,
        );
      }
      return module.isEnabled(config.features);
    }).toList(growable: false);
  }

  static final List<FeatureModule> _allModules = <FeatureModule>[
    HomeModule(),
    LiveModule(),
    FanzoneModule(),
    ChallengeModule(),
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
