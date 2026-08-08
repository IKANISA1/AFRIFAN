import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../extensions.dart';
import '../tokens/afri_semantic_colors.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/responsive_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_icon_button.dart';
import 'africlub_bottom_nav.dart';

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
    this.showAppBar = true,
    this.appBar,
    this.padding = AfriResponsive.scaffoldPadding,
    this.scrollable = true,
    this.constrainContent = true,
    this.bodyWrapper,
    this.bottomNavigationAware = false,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.restorationId,
    this.resizeToAvoidBottomInset = true,
    this.avoidDisplayFeatures = true,
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showAppBar;
  final PreferredSizeWidget? appBar;
  final EdgeInsets padding;
  final bool scrollable;
  final bool constrainContent;

  /// Optional full-body treatment, such as a route gradient, applied outside
  /// the responsive content-width constraint.
  final Widget Function(Widget child)? bodyWrapper;
  final bool bottomNavigationAware;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final String? restorationId;
  final bool resizeToAvoidBottomInset;
  final bool avoidDisplayFeatures;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final theme = Theme.of(context);
    final resolvedAppBar =
        appBar ??
        (showAppBar
            ? AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle:
                    (theme.brightness == Brightness.dark
                            ? SystemUiOverlayStyle.light
                            : SystemUiOverlayStyle.dark)
                        .copyWith(statusBarColor: Colors.transparent),
                leading: showBackButton
                    ? AfriIconButton(
                        icon: AfriIcons.back,
                        onTap: context.canPop() ? () => context.pop() : null,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                      )
                    : null,
                actions: actions,
              )
            : null);

    final body = _AfriScreenBody(
      title: title,
      padding: padding,
      scrollable: scrollable,
      constrainContent: constrainContent,
      bottomNavigationAware: bottomNavigationAware,
      colors: colors,
      theme: theme,
      child: child,
    );

    final hingeSafeBody = avoidDisplayFeatures
        ? DisplayFeatureSubScreen(child: body)
        : body;

    return Scaffold(
      restorationId: restorationId,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? colors.appBackground,
      appBar: resolvedAppBar,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        top: false,
        child: bodyWrapper?.call(hingeSafeBody) ?? hingeSafeBody,
      ),
    );
  }
}

class _AfriScreenBody extends StatelessWidget {
  const _AfriScreenBody({
    required this.child,
    required this.title,
    required this.padding,
    required this.scrollable,
    required this.constrainContent,
    required this.bottomNavigationAware,
    required this.colors,
    required this.theme,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final bool scrollable;
  final bool constrainContent;
  final bool bottomNavigationAware;
  final AfriSemanticColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (title != null) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final titleStyle = textScale >= 1.5
          ? theme.textTheme.headlineMedium
          : theme.textTheme.displayMedium;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title!.toUpperCase(),
              style: titleStyle?.copyWith(
                color: colors.primaryText,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: TypographyTokens.trackingNone,
                height: TypographyTokens.lineHeightHero,
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing8),
          if (scrollable) child else Expanded(child: child),
        ],
      );
    }

    final baseContent = content;
    return LayoutBuilder(
      builder: (context, constraints) {
        var resolvedContent = baseContent;
        if (constrainContent) {
          final maxWidth = AfriResponsive.maxContentWidthForWidth(
            constraints.maxWidth,
          );
          resolvedContent = Center(
            child: SizedBox(width: maxWidth, child: resolvedContent),
          );
        }

        if (scrollable) {
          final resolvedPadding = bottomNavigationAware
              ? padding.copyWith(
                  bottom:
                      padding.bottom +
                      AfriClubBottomNav.contentBottomInset(context),
                )
              : padding;
          return SingleChildScrollView(
            key: const ValueKey('afri-screen-scroll'),
            padding: resolvedPadding,
            child: resolvedContent,
          );
        }

        if (bottomNavigationAware) {
          resolvedContent = Padding(
            key: const ValueKey('afri-screen-bottom-inset'),
            padding: EdgeInsets.only(
              bottom: AfriClubBottomNav.contentBottomInset(context),
            ),
            child: resolvedContent,
          );
        }
        return resolvedContent;
      },
    );
  }
}
