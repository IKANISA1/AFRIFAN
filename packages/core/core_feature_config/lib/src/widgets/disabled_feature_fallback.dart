import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Fallback screen shown when a user navigates to a disabled feature's route.
///
/// Displays a friendly message with an option to go back. Used by the router
/// when a deep link or navigation targets a feature that has been disabled
/// by the admin configuration.
class DisabledFeatureFallback extends StatelessWidget {
  const DisabledFeatureFallback({
    this.featureName,
    this.message,
    this.onBack,
    super.key,
  });

  /// Display name of the feature (e.g. "Ticketing").
  final String? featureName;

  /// Custom message. Defaults to a generic unavailability message.
  final String? message;

  /// Called when the user taps the back/home button.
  /// If null, pops the current GoRouter route when one is available.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final featureLabel = featureName ?? 'This feature';

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: AfriStateView.empty(
              title: '$featureLabel is currently unavailable',
              message:
                  message ??
                  'This section has been temporarily disabled by the club administrators. Please check back later.',
              icon: AfriIcons.statusBlocked,
              actionLabel: 'Go back',
              onAction:
                  onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    }
                  },
            ),
          ),
        ),
      ),
    );
  }
}
