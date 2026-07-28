import 'dart:async';

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
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  Timer? _restoredTimer;
  bool _showRestored = false;
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    _restoredTimer?.cancel();

    if (!mounted) return;
    setState(() => _showRestored = restored);
    if (restored) {
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showRestored = false);
        }
      });
    }
  }

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
              child: isOnline && !_showRestored
                  ? const SizedBox.shrink()
                  : _ConnectionStatusBanner(isOnline: isOnline),
            ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final message = isOnline
        ? 'Connection restored. Refreshing current content.'
        : 'Offline. Content may be out of date. Network actions are unavailable.';
    final tone = isOnline ? ColorTokens.success : ColorTokens.warning;

    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Material(
        color: tone,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SizeTokens.touchTargetMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing4,
                vertical: SpacingTokens.spacing2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    isOnline
                        ? AfriIcons.statusSuccess
                        : AfriIcons.statusWarning,
                    size: AfriIcons.sizeChip,
                    color: ColorTokens.onDark,
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Flexible(
                    child: Text(
                      message,
                      style: TypographyTokens.labelSmall(ColorTokens.onDark),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds a small subtree whenever connection availability changes.
///
/// Use this for network-backed actions that must stay visible while offline
/// but become disabled with an explicit connection-required label.
class ConnectivityBuilder extends StatelessWidget {
  const ConnectivityBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool isOnline) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.onlineNotifier,
      builder: (context, isOnline, _) => builder(context, isOnline),
    );
  }
}
