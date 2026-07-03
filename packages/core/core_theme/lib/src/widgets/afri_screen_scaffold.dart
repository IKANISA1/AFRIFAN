import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../extensions.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/responsive_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_icon_button.dart';

/// Standardized screen scaffold with responsive layout, optional title,
/// and back button.
///
/// Wraps content in a [SingleChildScrollView] and caps width for
/// tablet/desktop layouts. Uses semantic colors for consistent theming.
///
/// ```dart
/// AfriScreenScaffold(
///   title: 'MATCH DETAILS',
///   child: MatchDetailContent(),
/// )
/// ```
class AfriScreenScaffold extends StatelessWidget {
  const AfriScreenScaffold({
    required this.child,
    this.title,
    this.actions,
    this.showBackButton = true,
    this.padding = AfriResponsive.scaffoldPadding,
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: showBackButton
            ? AfriIconButton(
                icon: AfriIcons.back,
                onTap: context.canPop() ? () => context.pop() : null,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              )
            : null,
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = AfriResponsive.maxContentWidthForWidth(
              constraints.maxWidth,
            );
            return SingleChildScrollView(
              padding: padding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Semantics(
                          header: true,
                          child: Text(
                            title!.toUpperCase(),
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: colors.primaryText,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0,
                              height: 0.9,
                            ),
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing8),
                      ],
                      child,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
