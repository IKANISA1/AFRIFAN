import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../extensions.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// A single action for [AfriActionSheet].
class AfriSheetAction {
  const AfriSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

/// Modal bottom sheet with a list of icon-led action rows.
///
/// Use for overflow menus, contextual card actions, and anywhere
/// multiple secondary actions need a clean entry point.
///
/// ```dart
/// showAfriActionSheet(
///   context: context,
///   title: 'Wallet',
///   actions: [
///     AfriSheetAction(icon: Icons.history, label: 'History', onTap: ...),
///     AfriSheetAction(icon: Icons.redeem, label: 'Rewards', onTap: ...),
///   ],
/// );
/// ```
Future<void> showAfriActionSheet({
  required BuildContext context,
  required List<AfriSheetAction> actions,
  String? title,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    builder: (ctx) => _AfriActionSheetBody(title: title, actions: actions),
  );
}

class _AfriActionSheetBody extends StatelessWidget {
  const _AfriActionSheetBody({this.title, required this.actions});

  final String? title;
  final List<AfriSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.overlaySurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.tertiaryText.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // ── Title ──
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.cardPadding,
                    SpacingTokens.spacing2,
                    SpacingTokens.cardPadding,
                    SpacingTokens.spacing3,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title!, style: TypographyTokens.sectionTitle()),
                  ),
                ),
              // ── Actions ──
              ...actions.map(
                (action) => AfriPressFeedback(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                    action.onTap();
                  },
                  semanticsLabel: action.label,
                  tooltip: action.label,
                  excludeChildSemantics: true,
                  builder: (context, state) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.cardPadding,
                      vertical: SpacingTokens.spacing4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                (action.destructive
                                        ? ColorTokens.error
                                        : ColorTokens.surfaceContainerHigh)
                                    .withValues(
                                      alpha: action.destructive ? 0.14 : 1.0,
                                    ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            action.icon,
                            size: 18,
                            color: action.destructive
                                ? ColorTokens.error
                                : colors.primaryText,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing4),
                        Expanded(
                          child: Text(
                            action.label,
                            style: TypographyTokens.titleSmall(
                              action.destructive ? ColorTokens.error : null,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: state.isFocused
                              ? ColorTokens.primaryContainer
                              : colors.tertiaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
            ],
          ),
        ),
      ),
    );
  }
}
