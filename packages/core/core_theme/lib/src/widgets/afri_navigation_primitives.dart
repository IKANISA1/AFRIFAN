import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../extensions.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_icon_button.dart';

class AfriSideRailDestination {
  const AfriSideRailDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool enabled;
}

/// Large-screen navigation rail with explicit compact and expanded modes.
class AfriSideRail extends StatelessWidget {
  const AfriSideRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
    this.header,
    this.footer,
    super.key,
  });

  final List<AfriSideRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    return NavigationRail(
      extended: extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (destinations[index].enabled) onDestinationSelected(index);
      },
      minWidth: AfriComponentSizes.compactMenuMinWidth,
      minExtendedWidth: 240,
      backgroundColor: colors.elevatedBackground,
      indicatorColor: colors.accentSoft,
      selectedIconTheme: IconThemeData(color: colors.accent),
      unselectedIconTheme: IconThemeData(color: colors.secondaryText),
      selectedLabelTextStyle: TypographyTokens.labelMedium(colors.primaryText),
      unselectedLabelTextStyle: TypographyTokens.labelMedium(
        colors.secondaryText,
      ),
      leading: header,
      trailing: footer == null ? null : Expanded(child: footer!),
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.selected,
      destinations: destinations
          .map(
            (destination) => NavigationRailDestination(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing2,
                vertical: SpacingTokens.spacing1 / 2,
              ),
              icon: Opacity(
                opacity: destination.enabled ? 1 : 0.48,
                child: Icon(destination.icon),
              ),
              selectedIcon: Opacity(
                opacity: destination.enabled ? 1 : 0.48,
                child: Icon(destination.selectedIcon),
              ),
              label: Opacity(
                opacity: destination.enabled ? 1 : 0.48,
                child: Text(destination.label),
              ),
            ),
          )
          .toList(),
    );
  }
}

class AfriBreadcrumbItem {
  const AfriBreadcrumbItem({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class AfriBreadcrumbs extends StatelessWidget {
  const AfriBreadcrumbs({required this.items, super.key});

  final List<AfriBreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Breadcrumb navigation',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SpacingTokens.spacing1,
        runSpacing: SpacingTokens.spacing1,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              const ExcludeSemantics(
                child: Icon(AfriIcons.chevronRight, size: AfriIcons.sizeInline),
              ),
            if (items[index].onTap == null)
              Semantics(
                currentValueLength: items[index].label.length,
                child: Text(
                  items[index].label,
                  style: TypographyTokens.labelMedium(ColorTokens.onSurface),
                ),
              )
            else
              TextButton(
                onPressed: items[index].onTap,
                child: Text(items[index].label),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shared restoration-safe back action with an optional route fallback.
class AfriBackButton extends StatelessWidget {
  const AfriBackButton({
    this.fallbackLocation,
    this.onPressed,
    this.tooltip = 'Back',
    this.enabled = true,
    super.key,
  });

  final String? fallbackLocation;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AfriIconButton(
      icon: AfriIcons.back,
      tooltip: tooltip,
      onTap: enabled
          ? onPressed ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  } else if (fallbackLocation != null) {
                    context.go(fallbackLocation!);
                  }
                }
          : null,
    );
  }
}
