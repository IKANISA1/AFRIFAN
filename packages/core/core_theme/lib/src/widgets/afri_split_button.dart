import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_button.dart';
import 'afri_popup_menu_button.dart';

/// A primary action paired with a separately reachable menu of alternatives.
class AfriSplitButton<T> extends StatelessWidget {
  const AfriSplitButton({
    required this.label,
    required this.onPressed,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.isLoading = false,
    this.menuTooltip = 'More actions',
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final IconData? icon;
  final bool enabled;
  final bool isLoading;
  final String menuTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AfriButton(
              label: label,
              icon: icon,
              onTap: onPressed,
              enabled: enabled && !isLoading,
              isLoading: isLoading,
              fullWidth: false,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing1),
          AfriPopupMenuButton<T>(
            enabled: enabled && !isLoading,
            tooltip: menuTooltip,
            itemBuilder: itemBuilder,
            onSelected: onSelected,
            child: Container(
              width: SizeTokens.touchTargetMin,
              height: SizeTokens.touchTargetMin,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled
                    ? colors.buttonPrimaryBackground
                    : colors.buttonPrimaryBackground.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                border: Border.fromBorderSide(
                  BorderTokens.side(
                    color: colors.borderStrong,
                    width: BorderTokens.standard,
                  ),
                ),
              ),
              child: Icon(
                AfriIcons.expandMore,
                color: enabled
                    ? colors.buttonPrimaryForeground
                    : colors.buttonPrimaryForeground.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
