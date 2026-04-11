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
    // Keep the home rail usable in test/offline states when config is absent.
    return true;
  }
});

/// Quick actions — horizontally scrollable row of tactile claymorphic circle icons.
///
/// Always one line, scrollable, with ellipsis for long names.
/// Items driven by the [actions] list — dynamic and extensible.
class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fantasyEnabled = ref
        .watch(_fantasyQuickActionEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);
    final actions = [
      _QuickAction(
        icon: Icons.confirmation_number_rounded,
        label: 'TICKETS',
        onTap: () => context.push('/tickets'),
      ),
      _QuickAction(
        icon: Icons.shopping_bag_rounded,
        label: 'SHOP',
        onTap: () => context.push('/shop'),
      ),
      _QuickAction(
        icon: Icons.groups_rounded,
        label: 'FAN CLUBS',
        onTap: () => context.push('/fan-clubs'),
      ),
      _QuickAction(
        icon: Icons.bolt_rounded,
        label: 'GAMES',
        onTap: () => context.push('/xp'),
      ),
      if (fantasyEnabled)
        _QuickAction(
          icon: Icons.emoji_events_rounded,
          label: 'FANTASY',
          onTap: () => context.push('/fantasy'),
        ),
      _QuickAction(
        icon: Icons.military_tech_rounded,
        label: 'MEMBERS',
        onTap: () => context.push('/membership'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Full-width SUPPORT pill ──
        ClaymorphicButton(
          label: 'SUPPORT',
          icon: Icons.volunteer_activism_rounded,
          width: double.infinity,
          onPressed: () => context.push('/contribute'),
        ),
        const SizedBox(height: SpacingTokens.spacing8),

        // ── Section header ──
        Row(
          children: [
            Expanded(
              child: Text(
                'QUICK ACTIONS',
                style: TypographyTokens.titleLarge().copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ColorTokens.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SWIPE',
                  style: TypographyTokens.labelSmall().copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.onSurface.withValues(alpha: 0.82),
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing1),
                Icon(
                  Icons.swipe_left_rounded,
                  size: 16,
                  color: ColorTokens.navActive.withValues(alpha: 0.9),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing5),

        // ── Horizontally scrollable row of circular icons ──
        SizedBox(
          height: _CircleActionButton.totalHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: SpacingTokens.spacing2),
            itemCount: actions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.spacing3),
            itemBuilder: (context, index) =>
                _CircleActionButton(action: actions[index]),
          ),
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

/// Tactile circular action with a violet clay core and soft ambient lift.
class _CircleActionButton extends StatelessWidget {
  final _QuickAction action;

  const _CircleActionButton({required this.action});

  /// Fixed tile width — gives enough room for icon + short label + ellipsis.
  static const double tileWidth = 96.0;

  /// Circle diameter.
  static const double circleSize = 58.0;

  /// Total height: circle + spacing + label line.
  static const double totalHeight = circleSize + 6 + 20;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      onTap: action.onTap,
      semanticsLabel: action.label,
      semanticsHint: 'Open ${action.label}',
      tooltip: action.label,
      excludeChildSemantics: true,
      builder: (context, state) => SizedBox(
        width: _CircleActionButton.tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: state.isPressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: _CircleActionButton.circleSize,
                height: _CircleActionButton.circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ColorTokens.primary, ColorTokens.primaryContainer],
                  ),
                  border: state.isFocused
                      ? BorderTokens.focusAll(
                          color: ColorTokens.onSurface,
                          opacity: 0.85,
                          width: 1.1,
                        )
                      : BorderTokens.ghost(opacity: 0.08),
                  boxShadow: state.isPressed
                      ? [
                          BoxShadow(
                            color: ColorTokens.ambientShadow.withValues(
                              alpha: 0.26,
                            ),
                            blurRadius: 12,
                            spreadRadius: -10,
                            offset: const Offset(-4, -4),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.08),
                            blurRadius: 12,
                            spreadRadius: -10,
                            offset: const Offset(4, 4),
                            blurStyle: BlurStyle.inner,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.18),
                            blurRadius: 18,
                            spreadRadius: -14,
                            offset: const Offset(-7, -8),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: ColorTokens.ambientShadow.withValues(
                              alpha: 0.30,
                            ),
                            blurRadius: 22,
                            spreadRadius: -14,
                            offset: const Offset(10, 12),
                            blurStyle: BlurStyle.inner,
                          ),
                          BoxShadow(
                            color: ColorTokens.primary.withValues(alpha: 0.22),
                            blurRadius: 28,
                            spreadRadius: -4,
                            offset: const Offset(0, 10),
                          ),
                        ],
                ),
                child: Center(
                  child: Icon(
                    action.icon,
                    color: ColorTokens.onSurface,
                    size: _CircleActionButton.circleSize * 0.42,
                  ),
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),

            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.labelMedium().copyWith(
                fontWeight: FontWeight.w700,
                color: ColorTokens.onSurface.withValues(alpha: 0.92),
                letterSpacing: 0.6,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
