import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tokens/spacing_tokens.dart';
import 'afri_skeleton.dart';
import 'afri_state_view.dart';

typedef AfriAsyncDataBuilder<T> = Widget Function(BuildContext context, T data);
typedef AfriAsyncErrorBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);
typedef AfriAsyncErrorMessageBuilder = String Function(Object error);

/// Standard Riverpod async-state renderer for AFRICLUB mobile routes.
///
/// Keeps loading and error treatment consistent while still allowing screens to
/// supply domain-specific skeletons or recovery UI.
class AfriAsyncStateView<T> extends StatelessWidget {
  const AfriAsyncStateView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.errorTitle = 'Unable to load',
    this.errorMessage = 'Please try again.',
    this.retryLabel = 'Try again',
    this.onRetry,
    this.errorMessageBuilder,
    this.loadingLabel = 'Loading',
    this.skeletonItemCount = 3,
    this.compact = false,
  });

  final AsyncValue<T> value;
  final AfriAsyncDataBuilder<T> data;
  final WidgetBuilder? loading;
  final AfriAsyncErrorBuilder? error;
  final String errorTitle;
  final String errorMessage;
  final String retryLabel;
  final VoidCallback? onRetry;
  final AfriAsyncErrorMessageBuilder? errorMessageBuilder;
  final String loadingLabel;
  final int skeletonItemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (resolved) => data(context, resolved),
      loading: () {
        final loadingBuilder = loading;
        if (loadingBuilder != null) {
          return loadingBuilder(context);
        }

        return Semantics(
          label: loadingLabel,
          liveRegion: true,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact
                  ? SpacingTokens.spacing2
                  : SpacingTokens.spacing4,
            ),
            child: AfriSkeletonList(
              itemCount: skeletonItemCount,
              spacing: compact
                  ? SpacingTokens.spacing2
                  : SpacingTokens.spacing3,
            ),
          ),
        );
      },
      error: (err, stackTrace) {
        final errorBuilder = error;
        if (errorBuilder != null) {
          return errorBuilder(context, err, stackTrace);
        }

        return AfriStateView.error(
          title: errorTitle,
          message: errorMessageBuilder?.call(err) ?? errorMessage,
          actionLabel: onRetry == null ? null : retryLabel,
          onAction: onRetry,
          compact: compact,
        );
      },
    );
  }
}
