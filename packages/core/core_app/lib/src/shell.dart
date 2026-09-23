import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Navigation shell — hosts the bottom nav and manages tab switching.
/// Labels stay visible at ordinary text sizes; enlarged text retains
/// accessible destination names with compact icons.
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
    final tabModules =
        modules
            .where(
              (module) =>
                  module.tabRoute != null &&
                  primaryBottomTabFeatureKeys.contains(module.featureKey),
            )
            .toList()
          ..sort(
            (left, right) => primaryBottomTabOrderForFeature(
              left.featureKey,
            ).compareTo(primaryBottomTabOrderForFeature(right.featureKey)),
          );
    // The primary supporter hierarchy is a governed product contract.
    // Runtime feature configuration may control content inside these tabs,
    // but cannot remove or reorder the navigation anchors themselves.
    final resolvedEntries = tabModules.asMap().entries.toList();
    final currentVisibleIndex = resolvedEntries.indexWhere(
      (entry) => entry.key == shell.currentIndex,
    );
    final isHiddenShellBranch = currentVisibleIndex < 0;
    final selectedIndex = currentVisibleIndex >= 0 ? currentVisibleIndex : 0;

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

    final navigationItems = resolvedEntries
        .map(
          (entry) => AfriClubNavItem(
            icon: entry.value.tabRoute!.icon,
            activeIcon: entry.value.tabRoute!.activeIcon,
            label: localizedPrimaryLabel(
              context.afriL10n,
              entry.value.featureKey,
              entry.value.tabRoute!.label,
            ),
          ),
        )
        .toList();

    void selectDestination(int index) {
      final branchIndex = resolvedEntries[index].key;
      shell.goBranch(
        branchIndex,
        initialLocation: branchIndex == shell.currentIndex,
      );
    }

    return DisplayFeatureSubScreen(
      key: const ValueKey('adaptive-app-shell'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usesSideRail =
              constraints.maxWidth >= AfriResponsive.sideRailMinWidth;
          if (isHiddenShellBranch) {
            return Scaffold(
              backgroundColor: ColorTokens.background,
              body: AfriShellNavigationScope(
                usesBottomNavigation: false,
                child: body,
              ),
            );
          }
          if (usesSideRail) {
            return Scaffold(
              backgroundColor: ColorTokens.background,
              body: Row(
                children: [
                  AfriSideRail(
                    destinations: navigationItems
                        .map(
                          (item) => AfriSideRailDestination(
                            label: item.label,
                            icon: item.icon,
                            selectedIcon: item.activeIcon ?? item.icon,
                          ),
                        )
                        .toList(),
                    selectedIndex: selectedIndex,
                    onDestinationSelected: selectDestination,
                    extended:
                        constraints.maxWidth >= AfriResponsive.expandedMaxWidth,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: AfriShellNavigationScope(
                      usesBottomNavigation: false,
                      child: body,
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: ColorTokens.background,
            extendBody: true,
            body: AfriShellNavigationScope(
              usesBottomNavigation: true,
              child: body,
            ),
            bottomNavigationBar: AfriClubBottomNav(
              currentIndex: selectedIndex,
              onTap: selectDestination,
              items: navigationItems,
            ),
          );
        },
      ),
    );
  }
}

@visibleForTesting
String localizedPrimaryLabel(
  AfriLocalizations l10n,
  String featureKey,
  String fallback,
) {
  return switch (featureKey) {
    'home' => l10n.navHome,
    'club' => l10n.navClub,
    'predict' => l10n.predictTitle,
    'membership' => l10n.navMembership,
    _ => fallback,
  };
}
