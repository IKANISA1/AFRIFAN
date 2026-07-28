import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

/// A single segment in [AfriSegmentedControl].
class AfriSegment {
  const AfriSegment({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Horizontal tab-like selector for filtering and mode switching.
///
/// Replaces ad-hoc text tab bars and toggle sets with a consistent,
/// accessible, animated control.
///
/// ```dart
/// AfriSegmentedControl(
///   items: [
///     AfriSegment(label: 'Week'),
///     AfriSegment(label: 'Month'),
///     AfriSegment(label: 'All'),
///   ],
///   selectedIndex: _selectedIndex,
///   onChanged: (index) => setState(() => _selectedIndex = index),
/// )
/// ```
class AfriSegmentedControl extends StatelessWidget {
  const AfriSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.disabledIndices = const <int>{},
  });

  final List<AfriSegment> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Set<int> disabledIndices;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final maxLabelLines = textScale >= 1.5 ? 2 : 1;
    final children = items
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == selectedIndex;
          return _buildSegment(
            context: context,
            item: item,
            index: index,
            isSelected: isSelected,
            enabled: !disabledIndices.contains(index),
            maxLabelLines: maxLabelLines,
          );
        })
        .toList(growable: false);

    final segmentedContent = items.length > 4
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: children
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(
                        right: AfriComponentSizes.segmentedInset,
                      ),
                      child: SizedBox(
                        width: _scrollItemWidth(context, items[entry.key]),
                        child: entry.value,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
        : Row(
            children: children.map((child) => Expanded(child: child)).toList(),
          );

    return Container(
      padding: const EdgeInsets.all(AfriComponentSizes.segmentedInset),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
      ),
      child: segmentedContent,
    );
  }

  double _scrollItemWidth(BuildContext context, AfriSegment item) {
    final textPainter = TextPainter(
      text: TextSpan(text: item.label, style: TypographyTokens.labelMedium()),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final iconWidth = item.icon == null
        ? 0
        : SizeTokens.iconXs + SpacingTokens.spacing1;
    final desiredWidth =
        textPainter.width + iconWidth + (SpacingTokens.spacing2 * 2);
    final viewportBound = MediaQuery.sizeOf(context).width * 0.85;
    final maxWidth = viewportBound < AfriComponentSizes.segmentedScrollItemWidth
        ? AfriComponentSizes.segmentedScrollItemWidth
        : viewportBound;
    return desiredWidth.clamp(
      AfriComponentSizes.segmentedScrollItemWidth,
      maxWidth,
    );
  }

  Widget _buildSegment({
    required BuildContext context,
    required AfriSegment item,
    required int index,
    required bool isSelected,
    required bool enabled,
    required int maxLabelLines,
  }) {
    return AfriPressFeedback(
      enabled: enabled,
      onTap: () {
        if (!isSelected) {
          unawaited(HapticFeedback.selectionClick());
          onChanged(index);
        }
      },
      selected: isSelected,
      semanticsLabel: item.label,
      excludeChildSemantics: true,
      builder: (context, state) => Opacity(
        opacity: enabled ? 1 : 0.48,
        child: AnimatedContainer(
          duration: AfriMotion.resolve(context, AfriMotion.quick),
          curve: AfriMotion.enterCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing2,
            vertical: SpacingTokens.spacing3,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? ColorTokens.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: ShapeTokens.segmentedInnerRadius,
            border: state.isFocused
                ? BorderTokens.focusAll(
                    color: ColorTokens.primaryContainer,
                    width: context.afriDesignTokens.focusRingWidth,
                  )
                : null,
            boxShadow: isSelected ? AfriShadows.selectedControl() : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: SizeTokens.iconXs,
                  color: isSelected
                      ? ColorTokens.primaryContainer
                      : ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing1),
              ],
              Flexible(
                child: Text(
                  item.label,
                  maxLines: maxLabelLines,
                  overflow: TextOverflow.ellipsis,
                  style: TypographyTokens.labelMedium(
                    isSelected
                        ? ColorTokens.onSurface
                        : ColorTokens.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
