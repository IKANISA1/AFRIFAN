import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../extensions.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
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
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;
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
///     AfriSheetAction(icon: AfriIcons.history, label: 'History', onTap: ...),
///     AfriSheetAction(icon: AfriIcons.rewards, label: 'Rewards', onTap: ...),
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
    sheetAnimationStyle: AfriMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (ctx) => AfriActionSheet(title: title, actions: actions),
  );
}

/// Embeddable action-sheet body used by the modal route and visual catalogs.
class AfriActionSheet extends StatelessWidget {
  const AfriActionSheet({this.title, required this.actions, super.key});

  final String? title;
  final List<AfriSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing3,
          SpacingTokens.spacing0,
          SpacingTokens.spacing3,
          SpacingTokens.spacing3,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.overlaySurface,
            borderRadius: ShapeTokens.inputRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: AfriComponentSizes.compactSheetHandleWidth,
                  height: SizeTokens.sheetHandleHeight,
                  margin: const EdgeInsets.only(
                    top: SpacingTokens.spacing3,
                    bottom: SpacingTokens.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tertiaryText.withValues(alpha: 0.5),
                    borderRadius: ShapeTokens.buttonRadius,
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
                  enabled: action.enabled,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.pop();
                    action.onTap();
                  },
                  semanticsLabel: action.label,
                  tooltip: action.label,
                  excludeChildSemantics: true,
                  builder: (context, state) => Opacity(
                    opacity: action.enabled ? 1 : 0.48,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.cardPadding,
                        vertical: SpacingTokens.spacing4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: AfriComponentSizes.actionSheetLeading,
                            height: AfriComponentSizes.actionSheetLeading,
                            decoration: BoxDecoration(
                              color:
                                  (action.destructive
                                          ? ColorTokens.error
                                          : ColorTokens.surfaceContainerHigh)
                                      .withValues(
                                        alpha: action.destructive ? 0.14 : 1.0,
                                      ),
                              borderRadius: BorderRadius.circular(
                                ShapeTokens.radiusControl,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              action.icon,
                              size: SizeTokens.iconSm,
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
                            AfriIcons.chevronRight,
                            size: SizeTokens.iconSm,
                            color: state.isFocused
                                ? ColorTokens.primaryContainer
                                : colors.tertiaryText,
                          ),
                        ],
                      ),
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
