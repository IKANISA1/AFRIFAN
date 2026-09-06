import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The governed route-state catalog used by router recovery surfaces.
enum RouteRecoveryVisualState {
  loading,
  empty,
  error,
  offline,
  permissionDenied,
  disabled,
  focused,
  pressed,
  selected,
  largeText,
  reducedMotion,
  dark,
  light,
  syncing,
  conflict,
  securityTimeout,
}

enum RouteRecoveryKind { featureUnavailable, routerError }

/// Privacy-safe recovery screen shared by feature gating and router failures.
///
/// Production callers normally use [RouteRecoveryVisualState.disabled] for a
/// feature gate and a typed error/offline/permission/timeout state for router
/// failures. The complete state catalog remains renderable so the system route
/// can be exercised under the same governed visual contract as feature routes.
class RouteRecoveryScreen extends StatelessWidget {
  const RouteRecoveryScreen({
    required this.kind,
    required this.fallbackLocation,
    this.visualState = RouteRecoveryVisualState.error,
    this.requestedPath,
    super.key,
  });

  final RouteRecoveryKind kind;
  final String fallbackLocation;
  final RouteRecoveryVisualState visualState;
  final String? requestedPath;

  static RouteRecoveryVisualState classifyRouterError(Object? error) {
    final normalized = error?.toString().toLowerCase() ?? '';
    if (normalized.contains('offline') ||
        normalized.contains('network') ||
        normalized.contains('socket')) {
      return RouteRecoveryVisualState.offline;
    }
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthor')) {
      return RouteRecoveryVisualState.permissionDenied;
    }
    if (normalized.contains('timeout') || normalized.contains('timed out')) {
      return RouteRecoveryVisualState.securityTimeout;
    }
    return RouteRecoveryVisualState.error;
  }

  String get _safeDestinationLabel {
    // A disabled/hidden feature must not be named from the deferred path:
    // feature visibility is itself part of the route policy.
    if (kind == RouteRecoveryKind.featureUnavailable) {
      return 'Requested section';
    }
    final path = requestedPath?.trim();
    if (path == null || path.isEmpty || !path.startsWith('/')) {
      return 'Requested page';
    }
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final firstSegment = segments.isEmpty ? null : segments.first;
    return switch (firstSegment) {
      'fanzone' => 'Fan Zone',
      'membership' => 'Membership',
      'tickets' => 'Tickets',
      'shop' => 'Shop',
      'settings' => 'Settings',
      'predict' => 'Predict',
      'contribute' => 'Supporters',
      'live' || 'live-match' => 'Live',
      'home' => 'Home',
      _ => 'Requested page',
    };
  }

  bool get _isSelected => visualState == RouteRecoveryVisualState.selected;

  bool get _showAction =>
      visualState != RouteRecoveryVisualState.loading &&
      visualState != RouteRecoveryVisualState.syncing;

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      scrollable: true,
      constrainContent: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                selected: _isSelected,
                label: '$_safeDestinationLabel requested',
                child: AnimatedContainer(
                  key: const ValueKey<String>('route-recovery-destination'),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing4,
                    vertical: SpacingTokens.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: _isSelected
                        ? context.afriSemanticColors.accent.withValues(
                            alpha: 0.14,
                          )
                        : context.afriSemanticColors.cardSurface,
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                    border: Border.all(
                      color: _isSelected
                          ? context.afriSemanticColors.accent
                          : context.afriSemanticColors.border,
                    ),
                  ),
                  child: Text(
                    _safeDestinationLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _isSelected
                          ? context.afriSemanticColors.accent
                          : context.afriSemanticColors.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              _buildState(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildState(BuildContext context) {
    final actionLabel = kind == RouteRecoveryKind.featureUnavailable
        ? 'Go back'
        : 'Go home';
    final action = _showAction ? () => context.go(fallbackLocation) : null;

    return switch (visualState) {
      RouteRecoveryVisualState.loading => AfriStateView.loading(
        title: 'Checking feature access',
        message: 'Please wait while the latest route policy is verified.',
        compact: false,
      ),
      RouteRecoveryVisualState.empty => AfriStateView.empty(
        title: 'No destination details',
        message:
            'This route has no public details yet. Return to a safe section.',
        actionLabel: actionLabel,
        onAction: action,
      ),
      RouteRecoveryVisualState.error => AfriStateView.error(
        title: kind == RouteRecoveryKind.featureUnavailable
            ? 'We could not check this feature.'
            : 'We could not open that page.',
        message:
            'No private error details are shown. Return and choose another section.',
        actionLabel: actionLabel,
        onAction: action,
      ),
      RouteRecoveryVisualState.offline => AfriStateView.offline(
        title: 'This route needs a connection.',
        message: 'Reconnect, then return and try the destination again.',
        actionLabel: actionLabel,
        onAction: action,
      ),
      RouteRecoveryVisualState.permissionDenied => AfriStateView.error(
        title: 'You do not have access.',
        message:
            'This destination is not available for the current account or role.',
        actionLabel: actionLabel,
        onAction: action,
      ),
      RouteRecoveryVisualState.syncing => AfriStateView.loading(
        title: 'Refreshing route access',
        message: 'Confirmed navigation remains paused while policy is checked.',
        compact: false,
      ),
      RouteRecoveryVisualState.conflict => AfriStateView.error(
        title: 'Route access changed.',
        message:
            'The destination changed while it was opening. Return and start again.',
        actionLabel: actionLabel,
        onAction: action,
      ),
      RouteRecoveryVisualState.securityTimeout => AfriStateView.error(
        title: 'The route check timed out.',
        message:
            'Nothing was opened. Return before trying the destination again.',
        actionLabel: actionLabel,
        onAction: action,
      ),
      _ => AfriDeepLinkRecovery(
        state: kind == RouteRecoveryKind.featureUnavailable
            ? AfriDeepLinkRecoveryState.unavailable
            : AfriDeepLinkRecoveryState.error,
        title: kind == RouteRecoveryKind.featureUnavailable
            ? 'This feature is currently unavailable.'
            : 'We could not open that page.',
        message: kind == RouteRecoveryKind.featureUnavailable
            ? 'The club has hidden or disabled this section for now.'
            : 'The requested route is unavailable.',
        actionLabel: actionLabel,
        onAction: action!,
        compact: false,
      ),
    };
  }
}
