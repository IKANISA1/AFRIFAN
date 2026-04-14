import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact home shortcuts with one primary CTA and a small action grid.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.sports_soccer_rounded,
        label: 'Predict',
        onTap: () => context.push('/fanzone/fixtures'),
      ),
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: 'My Picks',
        onTap: () => context.push('/fanzone/my'),
      ),
      _QuickAction(
        icon: Icons.live_tv_rounded,
        label: 'Live',
        onTap: () => context.push('/live'),
      ),
      _QuickAction(
        icon: Icons.leaderboard_outlined,
        label: 'Leaderboard',
        onTap: () => context.push('/fanzone/leaderboard'),
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Wallet',
        onTap: () => context.push('/fanzone/wallet'),
      ),
      _QuickAction(
        icon: Icons.confirmation_number_outlined,
        label: 'Tickets',
        onTap: () => context.push('/tickets'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AfriSectionHeader(
          title: 'Shortcuts',
          subtitle: 'Fast entry to core actions',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        ClaymorphicButton(
          label: 'Support',
          preserveCase: true,
          icon: Icons.volunteer_activism_outlined,
          width: double.infinity,
          onPressed: () => context.push('/contribute'),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = SpacingTokens.spacing3;
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
                      child: _QuickActionTile(action: action),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: action.onTap,
      semanticsLabel: action.label,
      semanticsHint: 'Open ${action.label}',
      tooltip: action.label,
      excludeChildSemantics: true,
      builder: (context, state) => ClayCard(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ColorTokens.primaryTint(state.isPressed ? 0.20 : 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                action.icon,
                size: 18,
                color: ColorTokens.primaryContainer,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.titleSmall(),
            ),
          ],
        ),
      ),
    );
  }
}
