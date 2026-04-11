import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _fantasyQuickActionEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    final client = ref.watch(supabaseClientProvider);
    final config = AppConfigRepository(client: client);
    return await config.isFeatureEnabled('fantasy_enabled');
  } catch (_) {
    return true;
  }
});

/// Compact home shortcuts with one primary CTA and a small action grid.
class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fantasyEnabled = ref
        .watch(_fantasyQuickActionEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);
    final actions = [
      _QuickAction(
        icon: Icons.confirmation_number_outlined,
        label: 'Tickets',
        onTap: () => context.push('/tickets'),
      ),
      _QuickAction(
        icon: Icons.shopping_bag_outlined,
        label: 'Shop',
        onTap: () => context.push('/shop'),
      ),
      _QuickAction(
        icon: Icons.groups_2_outlined,
        label: 'Fans',
        onTap: () => context.push('/fan-clubs'),
      ),
      _QuickAction(
        icon: Icons.bolt_rounded,
        label: 'Games',
        onTap: () => context.push('/xp'),
      ),
      if (fantasyEnabled)
        _QuickAction(
          icon: Icons.emoji_events_outlined,
          label: 'Fantasy',
          onTap: () => context.push('/fantasy'),
        ),
      _QuickAction(
        icon: Icons.workspace_premium_outlined,
        label: 'Members',
        onTap: () => context.push('/membership'),
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
