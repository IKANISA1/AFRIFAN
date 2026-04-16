import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/home_content_repository.dart';

/// Compact home shortcuts — icon-led action grid without verbose copy.
class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<HomeQuickAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureService = ref.watch(featureConfigServiceProvider);

    final filteredActions = actions.where((action) {
      // 1. Identify feature key from route or specific mapping
      final key = _featureKeyForRoute(action.route);
      // 2. Filter out if feature is explicitly disabled in runtime config
      return featureService.isFeatureEnabled(key);
    }).toList();

    if (filteredActions.isEmpty) {
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
            final columns = filteredActions.length <= 4 ? 2 : 3;
            final tileWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: filteredActions
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

  String _featureKeyForRoute(String route) {
    final path = route.trim().toLowerCase();
    if (path.contains('/fanzone')) return 'fanzone';
    if (path.contains('/BioPay')) return 'BioPay';
    if (path.contains('/live')) return 'live';
    if (path.contains('/shop')) return 'shop';
    if (path.contains('/tickets')) return 'ticketing';
    if (path.contains('/membership')) return 'membership';
    if (path.contains('/contribute')) return 'contributions';
    if (path.contains('/fan_clubs')) return 'fan_clubs';
    return 'home';
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
