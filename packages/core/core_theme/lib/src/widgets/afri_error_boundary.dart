import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_material_buttons.dart';

/// Widget-level error boundary that catches synchronous build errors
/// in its subtree and displays a recovery UI instead of the red error screen.
///
/// ```dart
/// AfriErrorBoundary(
///   onError: (error, stack) => crashlytics.recordError(error, stack),
///   onRetry: () => ref.invalidate(someProvider),
///   child: const ExpensiveWidget(),
/// )
/// ```
class AfriErrorBoundary extends StatefulWidget {
  const AfriErrorBoundary({
    required this.child,
    this.onError,
    this.onRetry,
    this.fallback,
    super.key,
  });

  final Widget child;
  final void Function(Object error, StackTrace? stack)? onError;
  final VoidCallback? onRetry;
  final Widget? fallback;

  @override
  State<AfriErrorBoundary> createState() => _AfriErrorBoundaryState();
}

class _AfriErrorBoundaryState extends State<AfriErrorBoundary> {
  bool _hasError = false;
  late ErrorWidgetBuilder _previousErrorWidgetBuilder;
  bool _restoreScheduled = false;

  @override
  void dispose() {
    if (identical(ErrorWidget.builder, _handleErrorWidget)) {
      ErrorWidget.builder = _previousErrorWidgetBuilder;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _BrandedErrorFallback(onRetry: _retry);
    }

    _installErrorWidgetBuilderForFrame();
    return widget.child;
  }

  void _retry() {
    setState(() => _hasError = false);
    widget.onRetry?.call();
  }

  void _installErrorWidgetBuilderForFrame() {
    final currentBuilder = ErrorWidget.builder;
    if (!identical(currentBuilder, _handleErrorWidget)) {
      _previousErrorWidgetBuilder = currentBuilder;
      ErrorWidget.builder = _handleErrorWidget;
    }
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (identical(ErrorWidget.builder, _handleErrorWidget)) {
        ErrorWidget.builder = _previousErrorWidgetBuilder;
      }
    });
  }

  Widget _handleErrorWidget(FlutterErrorDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasError) {
        setState(() => _hasError = true);
        widget.onError?.call(details.exception, details.stack);
        if (kDebugMode) {
          debugPrint('[AfriErrorBoundary] Caught: ${details.exception}');
        }
      }
    });
    return const SizedBox.shrink();
  }
}

class _BrandedErrorFallback extends StatelessWidget {
  const _BrandedErrorFallback({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.spacing8,
          vertical: SpacingTokens.spacing10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 40,
                color: colors.danger,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.primaryText,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'An unexpected error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.secondaryText,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: SpacingTokens.spacing6),
              AfriTextIconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Retry',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: AfriTextButton.styleFrom(foregroundColor: colors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
