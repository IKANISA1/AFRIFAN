import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
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
  late final ErrorWidgetBuilder _errorWidgetBuilder = _handleErrorWidget;
  _ErrorWidgetBuilderLease? _builderLease;

  @override
  void dispose() {
    _builderLease?.release();
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
    if (_builderLease?.isActive ?? false) return;
    final lease = _ErrorWidgetBuilderLease.install(_errorWidgetBuilder);
    _builderLease = lease;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      lease.release();
      if (identical(_builderLease, lease)) _builderLease = null;
    });
  }

  Widget _handleErrorWidget(FlutterErrorDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasError) {
        setState(() => _hasError = true);
        widget.onError?.call(details.exception, details.stack);
        if (kDebugMode) {
          debugPrint('[AfriErrorBoundary] runtime_failure');
        }
      }
    });
    return const SizedBox.shrink();
  }
}

/// Frame leases may be released parent first while a nested boundary still
/// owns the global builder. Keep the previous lease so a later child release
/// skips inactive ancestors instead of reinstalling their stale callbacks.
class _ErrorWidgetBuilderLease {
  _ErrorWidgetBuilderLease._(
    this.builder,
    this._previousBuilder,
    this._previousLease,
  );

  static final _installed =
      Map<ErrorWidgetBuilder, _ErrorWidgetBuilderLease>.identity();
  final ErrorWidgetBuilder builder;
  final ErrorWidgetBuilder _previousBuilder;
  final _ErrorWidgetBuilderLease? _previousLease;
  bool _active = true;

  bool get isActive => _active;

  static _ErrorWidgetBuilderLease install(ErrorWidgetBuilder builder) {
    final previous = ErrorWidget.builder;
    final lease = _ErrorWidgetBuilderLease._(
      builder,
      previous,
      _installed[previous],
    );
    _installed[builder] = lease;
    ErrorWidget.builder = builder;
    return lease;
  }

  ErrorWidgetBuilder get _restorationTarget {
    final previous = _previousLease;
    if (previous == null) return _previousBuilder;
    return previous.isActive ? previous.builder : previous._restorationTarget;
  }

  void release() {
    if (!_active) return;
    _active = false;
    if (identical(_installed[builder], this)) _installed.remove(builder);
    if (identical(ErrorWidget.builder, builder)) {
      ErrorWidget.builder = _restorationTarget;
    }
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
              width: AfriComponentSizes.errorGraphic,
              height: AfriComponentSizes.errorGraphic,
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AfriIcons.statusWarning,
                size: SizeTokens.iconHero,
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
                height: TypographyTokens.lineHeightRelaxed,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: SpacingTokens.spacing6),
              AfriTextIconButton(
                onPressed: onRetry,
                icon: const Icon(AfriIcons.refresh, size: SizeTokens.iconSm),
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
