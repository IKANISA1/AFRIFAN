import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Renders the production navigation primitive in isolated route captures.
/// Real tab switching remains covered by the app-shell navigation tests.
class TabShellFixture extends StatelessWidget {
  const TabShellFixture({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  static const items = [
    AfriClubNavItem(icon: AfriIcons.home, label: 'Home'),
    AfriClubNavItem(icon: AfriIcons.stadium, label: 'Club'),
    AfriClubNavItem(icon: AfriIcons.predict, label: 'Predict'),
    AfriClubNavItem(icon: AfriIcons.membership, label: 'Membership'),
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rail = constraints.maxWidth >= AfriResponsive.sideRailMinWidth;
      final content = AfriShellNavigationScope(
        usesBottomNavigation: !rail,
        child: child,
      );
      return Scaffold(
        extendBody: !rail,
        body: rail
            ? Row(
                children: [
                  AfriSideRail(
                    destinations: items
                        .map(
                          (item) => AfriSideRailDestination(
                            label: item.label,
                            icon: item.icon,
                            selectedIcon: item.icon,
                          ),
                        )
                        .toList(),
                    selectedIndex: index,
                    onDestinationSelected: (_) {},
                    extended:
                        constraints.maxWidth >= AfriResponsive.expandedMaxWidth,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: rail
            ? null
            : AfriClubBottomNav(
                currentIndex: index,
                onTap: (_) {},
                items: items,
              ),
      );
    },
  );
}
