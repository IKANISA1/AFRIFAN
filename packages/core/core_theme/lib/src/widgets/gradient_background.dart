import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/afri_semantic_colors.dart';
import '../tokens/color_tokens.dart';

/// Full-screen route background using the mapped Revolut colour families.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final String? routePath;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.routePath,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = colors == null
        ? ColorTokens.screenGradientForPath(
            routePath,
            Theme.of(context).brightness,
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors!,
          );

    final route = Uri.tryParse(routePath ?? '')?.path;
    final overview = const ['/home', '/club', '/predict'].contains(route);
    final auth = const ['/auth/phone', '/auth/otp'].contains(route);
    final theme = Theme.of(context);
    final semantic = context.afriSemanticColors;
    final content = (overview || auth) && theme.brightness == Brightness.dark
        ? Theme(
            data: theme.copyWith(
              extensions: [
                for (final extension in theme.extensions.values)
                  if (extension is! AfriSemanticColors) extension,
                semantic.copyWith(
                  inputSurface: auth
                      ? ColorTokens.onDark.withValues(alpha: 0.20)
                      : semantic.inputSurface,
                  cardSurface: overview
                      ? ColorTokens.overviewSurfaceForPath(route!)
                      : semantic.cardSurface,
                  cardSurfaceStrong: overview
                      ? Color.alphaBlend(
                          ColorTokens.onDark.withValues(alpha: 0.12),
                          ColorTokens.overviewSurfaceForPath(route!),
                        )
                      : semantic.cardSurfaceStrong,
                  secondaryText: ColorTokens.onDark.withValues(
                    alpha: auth ? 0.85 : 0.9,
                  ),
                  tertiaryText: ColorTokens.onDark.withValues(alpha: 0.75),
                ),
              ],
            ),
            child: child,
          )
        : child;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        content,
      ],
    );
  }
}
