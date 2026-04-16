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
                      color: Colors.orange.shade800,
                      child: SafeArea(
                        bottom: false,
                        child: const SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'No internet connection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
