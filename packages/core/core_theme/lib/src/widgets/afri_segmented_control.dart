import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/color_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

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
  });

  final List<AfriSegment> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.selectionClick();
                  onChanged(index);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                selected: isSelected,
                label: item.label,
                child: AnimatedContainer(
                  duration: AfriMotion.quick,
                  curve: AfriMotion.enterCurve,
                  padding: const EdgeInsets.symmetric(
                    vertical: SpacingTokens.spacing3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ColorTokens.surfaceContainerLowest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: ColorTokens.ambientShadow
                                  .withValues(alpha: 0.12),
                              blurRadius: 8,
                              spreadRadius: -4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.icon != null) ...[
                        Icon(
                          item.icon,
                          size: 14,
                          color: isSelected
                              ? ColorTokens.primaryContainer
                              : ColorTokens.onSurfaceVariant,
                        ),
                        const SizedBox(width: SpacingTokens.spacing1),
                      ],
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.labelMedium(
                          isSelected
                              ? ColorTokens.onSurface
                              : ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
