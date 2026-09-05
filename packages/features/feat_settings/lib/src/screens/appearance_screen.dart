import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// A local draft: browsing modes never changes or persists the app preference.
/// LIVE-010/011 supply the preview, mode choice and Cancel/Apply interaction.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key, required this.initialMode});

  final ThemeMode initialMode;

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late ThemeMode _draft = widget.initialMode;
  final _pages = PageController(
    viewportFraction: AfriComponentSizes.themePreviewViewportFraction,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final colors = context.afriSemanticColors;
    final brightness = switch (_draft) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    return Scaffold(
      appBar: AfriAppBar(
        title: Text(l10n.settingsThemePreview),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: (constraints.maxHeight * 0.67).clamp(
                    AfriComponentSizes.themePreviewMinHeight,
                    AfriComponentSizes.themePreviewMaxHeight,
                  ),
                  child: PageView(
                    controller: _pages,
                    children: [
                      for (final route in [
                        '/home',
                        '/club',
                        '/fanzone',
                        '/membership',
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing4,
                            vertical: SpacingTokens.spacing6,
                          ),
                          child: _ThemePreview(
                            route: route,
                            brightness: brightness,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.screenPadding,
                  ),
                  child: Text(
                    l10n.settingsAppearanceMessage,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.bodyMedium(colors.secondaryText),
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: SpacingTokens.spacing6,
                  runSpacing: SpacingTokens.spacing3,
                  children: [
                    for (final mode in [
                      ThemeMode.light,
                      ThemeMode.dark,
                      ThemeMode.system,
                    ])
                      _ModeChoice(
                        mode: mode,
                        selected: _draft == mode,
                        label: switch (mode) {
                          ThemeMode.light => l10n.settingsThemeLight,
                          ThemeMode.dark => l10n.settingsThemeDark,
                          ThemeMode.system => l10n.settingsThemeSystem,
                        },
                        onTap: () => setState(() => _draft = mode),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: AfriButton(
                          key: const ValueKey('appearance-cancel'),
                          label: l10n.settingsCancel,
                          variant: AfriButtonVariant.secondary,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: AfriButton(
                          key: const ValueKey('appearance-apply'),
                          label: l10n.settingsApplyTheme,
                          enabled: _draft != widget.initialMode,
                          onTap: () => Navigator.of(context).pop(_draft),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.mode,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: AfriPressFeedback(
      key: ValueKey('appearance-mode-${mode.name}'),
      semanticsLabel: label,
      excludeChildSemantics: true,
      onTap: onTap,
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: SizeTokens.touchTargetMin,
            height: SizeTokens.touchTargetMin,
            padding: const EdgeInsets.all(SpacingTokens.spacing1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected || state.isFocused
                  ? BorderTokens.all(
                      color: context.afriSemanticColors.primaryText,
                      width: BorderTokens.emphasis,
                    )
                  : null,
            ),
            child: ClipOval(
              child: Row(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: mode == ThemeMode.dark
                          ? ColorTokens.inkBase
                          : ColorTokens.paperSurface,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: mode == ThemeMode.light
                          ? ColorTokens.paperSurface
                          : ColorTokens.inkBase,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(label, style: TypographyTokens.bodyMedium()),
        ],
      ),
    ),
  );
}

/// Schematic previews show the app's own four canvases, never account data.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.route, required this.brightness});
  final String route;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final foreground = brightness == Brightness.dark
        ? ColorTokens.onDark
        : ColorTokens.inkBase;
    final tone = foreground.withValues(alpha: 0.15);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ColorTokens.screenGradientForPath(route, brightness),
          borderRadius: ShapeTokens.heroCardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing4),
          child: Column(
            children: [
              Row(
                children: [
                  _dot(tone),
                  const SizedBox(width: SpacingTokens.spacing4),
                  Expanded(
                    child: Container(
                      height: AfriComponentSizes.themePreviewCommand,
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: ShapeTokens.buttonRadius,
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing4),
                  _dot(tone),
                ],
              ),
              const Spacer(),
              Text(
                ClubConfigScope.maybeOf(context)?.appName ??
                    context.afriL10n.appTitle,
                textAlign: TextAlign.center,
                style: TypographyTokens.titleLarge(foreground),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (_) => _dot(tone)),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: ShapeTokens.cardRadius,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: AfriComponentSizes.themePreviewCommand,
    height: AfriComponentSizes.themePreviewCommand,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
