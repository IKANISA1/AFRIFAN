import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import 'connectivity_service.dart';

/// A slim banner that appears at the top of the screen when offline.
///
/// Wrap your scaffold body with this widget — it adds a non-intrusive
/// offline indicator that auto-dismisses when connectivity returns.
///
/// ```dart
/// Scaffold(
///   body: OfflineBanner(
///     child: MyContent(),
///   ),
/// )
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.onlineNotifier,
      builder: (context, isOnline, _) {
        return Column(
          children: <Widget>[
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isOnline
                  ? const SizedBox.shrink()
                  : Material(
                      color: ColorTokens.warning,
                      child: SafeArea(
                        bottom: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  AfriIcons.statusWarning,
                                  size: AfriIcons.sizeChip,
                                  color: ColorTokens.onDark,
                                ),
                                const SizedBox(width: SpacingTokens.spacing2),
                                Text(
                                  'Connection unavailable',
                                  style: TypographyTokens.labelSmall(
                                    ColorTokens.onDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
