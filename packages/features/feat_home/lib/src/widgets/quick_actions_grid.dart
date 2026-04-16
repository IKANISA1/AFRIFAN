import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/home_content_repository.dart';

/// Compact home shortcuts — icon-led action grid without verbose copy.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<HomeQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AfriSectionHeader(title: 'Shortcuts', padding: EdgeInsets.zero),
        const SizedBox(height: SpacingTokens.spacing4),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = SpacingTokens.listItemGap;
            final columns = actions.length <= 4 ? 2 : 3;
            final tileWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: tileWidth,
                      child: AfriActionRow(
                        icon: _resolveActionIcon(action),
                        label: action.title,
                        onTap: () => context.push(action.route),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  IconData _resolveActionIcon(HomeQuickAction action) {
    return switch (action.iconKey.trim()) {
      'groups' => AfriIcons.groups,
      'predict' => AfriIcons.predict,
      'tickets' => AfriIcons.tickets,
      'shop' => AfriIcons.shop,
      'members' => AfriIcons.members,
      'myPicks' => AfriIcons.myPicks,
      'live' => AfriIcons.live,
      'leaderboard' => AfriIcons.leaderboard,
      'wallet' => AfriIcons.wallet,
      'contribute' => AfriIcons.groups,
      'league' => AfriIcons.league,
      'clubZone' => AfriIcons.clubZone,
      'notifications' => AfriIcons.notifications,
      'history' => AfriIcons.history,
      'rewards' => AfriIcons.rewards,
      'offers' => AfriIcons.offers,
      'membership' => AfriIcons.membership,
      _ => _fallbackIconForRoute(action.route),
    };
  }

  IconData _fallbackIconForRoute(String route) {
    final normalized = route.trim().toLowerCase();
    if (normalized.contains('/fanzone/fixtures')) return AfriIcons.predict;
    if (normalized.contains('/fanzone/my')) return AfriIcons.myPicks;
    if (normalized.contains('/live')) return AfriIcons.live;
    if (normalized.contains('/leaderboard')) return AfriIcons.leaderboard;
    if (normalized.contains('/wallet')) return AfriIcons.wallet;
    if (normalized.contains('/tickets')) return AfriIcons.tickets;
    if (normalized.contains('/fanzone/offers')) return AfriIcons.offers;
    if (normalized.contains('/contribute')) return AfriIcons.groups;
    return AfriIcons.chevronRight;
  }
}
