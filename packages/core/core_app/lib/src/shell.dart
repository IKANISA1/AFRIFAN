import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation shell — hosts the bottom nav and manages tab switching.
///
/// "Icon-only by default. On press: icon scales up (1.2x),
/// label appears below, haptic 'pop' triggered."
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tabs = modules
        .where((m) => m.tabRoute != null)
        .map((m) => m.tabRoute!)
        .toList();

    return Scaffold(
      backgroundColor: ColorTokens.background,
      extendBody: true,
      body: shell,
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
