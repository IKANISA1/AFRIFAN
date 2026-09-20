import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/home_content_repository.dart';

/// Compact home shortcuts — icon-led action grid without verbose copy.
class QuickActionsGrid extends ConsumerStatefulWidget {
  const QuickActionsGrid({super.key, required this.actions});

  static const int maxPrimaryActions = 4;

  final List<HomeQuickAction> actions;

  @override
  ConsumerState<QuickActionsGrid> createState() => _QuickActionsGridState();
}

@visibleForTesting
List<HomeQuickAction> prioritizeHomeQuickActions(
  Iterable<HomeQuickAction> actions,
) {
  final prioritized = actions.toList(growable: false);
  return prioritized.toList()..sort((left, right) {
    final rankComparison = _homeActionRank(
      left,
    ).compareTo(_homeActionRank(right));
    if (rankComparison != 0) return rankComparison;
    final configuredOrder = left.sortOrder.compareTo(right.sortOrder);
    if (configuredOrder != 0) return configuredOrder;
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  });
}

int _homeActionRank(HomeQuickAction action) {
  final key = action.actionKey.trim().toLowerCase();
  final route = action.route.trim().toLowerCase();
  if (key.contains('ticket') || route.startsWith('/tickets')) return 10;
  if (key.contains('membership') || route.startsWith('/membership')) return 20;
  if (key == 'fan_zone' ||
      key.contains('supporter') ||
      route == '/predict' ||
      route.startsWith('/predict?') ||
      route == '/fanzone' ||
      route.startsWith('/fanzone?')) {
    return 30;
  }
  if (key.contains('shop') || route.startsWith('/shop')) return 40;
  return 100;
}

class _QuickActionsGridState extends ConsumerState<QuickActionsGrid> {
  bool _showSecondaryActions = false;

  @override
  Widget build(BuildContext context) {
    final featureService = ref.watch(featureConfigServiceProvider);
    final l10n = context.afriL10n;

    final visibleActions = prioritizeHomeQuickActions(
      widget.actions.where((action) {
        if (!action.isActive ||
            _localizedHomeActionTitle(l10n, action).trim().isEmpty ||
            action.route.trim().isEmpty) {
          return false;
        }
        final featureKey = featureService.getFeatureKeyForPath(action.route);
        return featureKey == null ||
            featureService.getFeatureAccess(featureKey).isVisible;
      }),
    );
    final primaryActions = visibleActions
        .take(QuickActionsGrid.maxPrimaryActions)
        .toList(growable: false);
    final secondaryActions = visibleActions
        .skip(QuickActionsGrid.maxPrimaryActions)
        .toList(growable: false);

    if (primaryActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PrimaryActionGrid(
          actions: primaryActions,
          resolveIcon: _resolveActionIcon,
          isAvailable: (action) =>
              featureService.isRouteAvailable(action.route),
          onTap: (action) => _openAction(context, action, layer: 'primary'),
        ),
        if (secondaryActions.isNotEmpty) ...[
          AfriSectionHeader(
            title: l10n.homeShortcutsTitle,
            padding: EdgeInsets.zero,
            trailing: secondaryActions.isEmpty
                ? null
                : AfriButton(
                    key: const ValueKey<String>(
                      'home-secondary-actions-toggle',
                    ),
                    label: _showSecondaryActions
                        ? l10n.homeLess
                        : l10n.homeMore,
                    semanticsLabel: _showSecondaryActions
                        ? l10n.homeHideMoreShortcuts
                        : l10n.homeShowMoreShortcuts,
                    onTap: () {
                      setState(() {
                        _showSecondaryActions = !_showSecondaryActions;
                      });
                    },
                    variant: AfriButtonVariant.ghost,
                    fullWidth: false,
                  ),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
        ],
        if (_showSecondaryActions && secondaryActions.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing6),
          const AfriDivider(),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(l10n.homeMoreShortcuts, style: TypographyTokens.titleSmall()),
          const SizedBox(height: SpacingTokens.spacing3),
          _SecondaryActionGrid(
            actions: secondaryActions,
            resolveIcon: _resolveActionIcon,
            isAvailable: (action) =>
                featureService.isRouteAvailable(action.route),
            onTap: (action) => _openAction(context, action, layer: 'secondary'),
          ),
        ],
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
    if (normalized.startsWith('/predict')) return AfriIcons.predict;
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

  void _openAction(
    BuildContext context,
    HomeQuickAction action, {
    required String layer,
  }) {
    unawaited(
      FirebaseAnalyticsService.logHomeActionSelected(
        action: action.actionKey,
        layer: layer,
      ),
    );
    if (_isPrimaryTabRoute(action.route)) {
      context.go(action.route);
      return;
    }
    unawaited(context.push(action.route));
  }

  bool _isPrimaryTabRoute(String route) {
    final normalized = Uri.tryParse(route.trim().toLowerCase())?.path;
    if (normalized == '/predict') return true;
    return primaryBottomTabFeatureOrder.any((featureKey) {
      return normalized == '/$featureKey';
    });
  }
}

class _PrimaryActionGrid extends StatelessWidget {
  const _PrimaryActionGrid({
    required this.actions,
    required this.resolveIcon,
    required this.isAvailable,
    required this.onTap,
  });

  final List<HomeQuickAction> actions;
  final IconData Function(HomeQuickAction action) resolveIcon;
  final bool Function(HomeQuickAction action) isAvailable;
  final ValueChanged<HomeQuickAction> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = SpacingTokens.spacing3;
        final useTwoColumns =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final columns = useTwoColumns
            ? 2
            : actions.length.clamp(1, QuickActionsGrid.maxPrimaryActions);
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          key: ValueKey<String>('home-primary-actions-${columns}col'),
          spacing: spacing,
          runSpacing: SpacingTokens.spacing4,
          children: actions
              .map((action) {
                final available = isAvailable(action);
                final title = _localizedHomeActionTitle(
                  context.afriL10n,
                  action,
                );
                return SizedBox(
                  key: ValueKey<String>(
                    'home-primary-action-${action.actionKey}',
                  ),
                  width: tileWidth,
                  child: AfriQuickAction(
                    icon: resolveIcon(action),
                    label: available
                        ? title
                        : context.afriL10n.homeActionUnavailable(title),
                    enabled: available,
                    semanticsHint: available
                        ? context.afriL10n.homeActionOpensHint(title)
                        : context.afriL10n.homeActionUnavailableHint(title),
                    onTap: () => onTap(action),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _SecondaryActionGrid extends StatelessWidget {
  const _SecondaryActionGrid({
    required this.actions,
    required this.resolveIcon,
    required this.isAvailable,
    required this.onTap,
  });

  final List<HomeQuickAction> actions;
  final IconData Function(HomeQuickAction action) resolveIcon;
  final bool Function(HomeQuickAction action) isAvailable;
  final ValueChanged<HomeQuickAction> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = SpacingTokens.listItemGap;
        final columns =
            constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 1
            : 2;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          key: ValueKey<String>('home-secondary-actions-${columns}col'),
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((action) {
                final available = isAvailable(action);
                final title = _localizedHomeActionTitle(
                  context.afriL10n,
                  action,
                );
                return SizedBox(
                  width: tileWidth,
                  child: AfriActionRow(
                    icon: resolveIcon(action),
                    label: available
                        ? title
                        : context.afriL10n.homeActionUnavailableInline(title),
                    enabled: available,
                    onTap: () => onTap(action),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

String _localizedHomeActionTitle(
  AfriLocalizations l10n,
  HomeQuickAction action,
) {
  final configuredTitle = action.title.trim();
  final path = Uri.tryParse(action.route.trim())?.path;
  if ((path == '/fanzone' || path == '/challenge' || path == '/predict') &&
      const {
        'fan zone',
        'fanzone',
        'challenge',
        'predict',
      }.contains(configuredTitle.toLowerCase())) {
    return l10n.predictTitle;
  }
  if (configuredTitle.isNotEmpty) {
    return configuredTitle;
  }
  final key = action.actionKey.trim().toLowerCase();
  final route = action.route.trim().toLowerCase();
  if (key.contains('ticket') || route.startsWith('/tickets')) {
    return l10n.homeTicketsAction;
  }
  if (key.contains('membership') || route.startsWith('/membership')) {
    return l10n.homeMembershipAction(RuntimeBranding.displayAppName);
  }
  if (key == 'fan_zone' ||
      key.contains('supporter') ||
      route == '/predict' ||
      route.startsWith('/predict?') ||
      route == '/fanzone' ||
      route.startsWith('/fanzone?')) {
    return l10n.homeFanZoneAction;
  }
  if (key.contains('shop') || route.startsWith('/shop')) {
    return l10n.homeShopAction;
  }
  return configuredTitle;
}
