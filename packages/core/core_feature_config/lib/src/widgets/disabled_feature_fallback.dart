import 'package:flutter/material.dart';

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
  /// If null, uses [Navigator.maybePop].
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featureLabel = featureName ?? 'This feature';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.construction_rounded,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$featureLabel is currently unavailable',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'This section has been temporarily disabled by the club administrators. '
                          'Please check back later.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
