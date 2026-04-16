import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Navigation shell — hosts the bottom nav and manages tab switching.
///
/// "Icon-only by default. On press: icon scales up (1.2x),
/// label appears below, haptic 'pop' triggered."
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  final ClubConfig config;
  final List<FeatureModule> modules;

  const AppShell({
    super.key,
    required this.shell,
    required this.config,
    required this.modules,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Resolve Tabs from Config ──
    final navFeatures = ref.watch(navFeaturesProvider);
    final List<TabRoute> tabs;

    if (navFeatures.isNotEmpty) {
      // Map sorted config features back to module tab routes
      tabs = navFeatures.map((f) {
        return modules
            .firstWhere((m) => m.featureKey == f.featureKey)
            .tabRoute!;
      }).toList();
    } else {
      // Fallback to static module order
      tabs = modules
          .where((m) => m.tabRoute != null)
          .map((m) => m.tabRoute!)
          .toList();
    }

    // In release/profile builds, wrap each tab's content in an error boundary
    // so a crash in one tab does not take down the entire shell.
    final body = (kReleaseMode || kProfileMode)
        ? AfriErrorBoundary(
            onError: (error, stack) {
              AfriLogger.error(
                'AppShell',
                'Caught tab-level widget error.',
                error,
                stack,
              );
              unawaited(CrashlyticsService.recordError(error, stack));
            },
            child: shell,
          )
        : shell;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      extendBody: true,
      body: body,
      bottomNavigationBar: AfriClubBottomNav(
        currentIndex: shell.currentIndex,
        onTap: (index) {
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
        items: tabs
            .map(
              (tab) => AfriClubNavItem(
                icon: tab.icon,
                activeIcon: tab.activeIcon,
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
