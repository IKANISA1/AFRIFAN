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
    final featureService = ref.watch(featureConfigServiceProvider);
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
    final visibleEntries = tabModules.asMap().entries.where((entry) {
      final feature = featureService.getFeature(entry.value.featureKey);
      if (!featureService.hasConfig || feature == null) {
        return true;
      }
      return featureService.shouldShowInNav(entry.value.featureKey);
    }).toList();

    final resolvedEntries = visibleEntries.isNotEmpty
        ? visibleEntries
        : tabModules.asMap().entries.toList();
    final currentVisibleIndex = resolvedEntries.indexWhere(
      (entry) => entry.key == shell.currentIndex,
    );
    if (currentVisibleIndex < 0 &&
        resolvedEntries.isNotEmpty &&
        shell.currentIndex != resolvedEntries.first.key) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        shell.goBranch(resolvedEntries.first.key);
      });
    }
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
            label: entry.value.tabRoute!.label,
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
