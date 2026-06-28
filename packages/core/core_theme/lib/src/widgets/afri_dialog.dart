import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'glass_card.dart';

/// Shared borrowed modal dialog surface.
class AfriDialog extends StatelessWidget {
  const AfriDialog({
    required this.child,
    this.padding = const EdgeInsets.all(SpacingTokens.spacing5),
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: SpacingTokens.spacing5,
      vertical: SpacingTokens.spacing5,
    ),
    this.constraints = const BoxConstraints(maxWidth: 560),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsets insetPadding;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColorTokens.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      shape: RoundedRectangleBorder(borderRadius: ShapeTokens.cardRadius),
      child: ConstrainedBox(
        constraints: constraints,
        child: GlassCard(animate: false, padding: padding, child: child),
      ),
    );
  }
}

/// Borrowed-system replacement for feature-level [AlertDialog] usage.
class AfriAlertDialog extends StatelessWidget {
  const AfriAlertDialog({
    this.title,
    this.content,
    this.actions = const <Widget>[],
    this.scrollable = false,
    this.padding = const EdgeInsets.all(SpacingTokens.spacing5),
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          DefaultTextStyle(style: TypographyTokens.titleLarge(), child: title!),
        if (title != null && content != null)
          const SizedBox(height: SpacingTokens.spacing4),
        if (content != null)
          Flexible(
            fit: FlexFit.loose,
            child: DefaultTextStyle(
              style: TypographyTokens.bodyMedium(),
              child: scrollable
                  ? SingleChildScrollView(child: content)
                  : content!,
            ),
          ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing5),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: actions,
          ),
        ],
      ],
    );

    return AfriDialog(padding: padding, child: body);
  }
}
