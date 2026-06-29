import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// In-app notification toast that auto-appears as a top banner when triggered.
///
/// Mirrors the fanafrika reference `NotificationToast.tsx` — animated entrance,
/// auto-hides after [autoDismissDuration] seconds, supports type-differentiated
/// icons (challenge → swords, settlement → trophy, system → bell).
class NotificationToastOverlay extends StatefulWidget {
  const NotificationToastOverlay({super.key, required this.child});

  final Widget child;

  /// Show a toast from any descendant using this static method.
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String type = 'system',
    Duration autoDismissDuration = const Duration(seconds: 4),
  }) {
    final state = context
        .findAncestorStateOfType<_NotificationToastOverlayState>();
    state?._showToast(
      title: title,
      message: message,
      type: type,
      autoDismissDuration: autoDismissDuration,
    );
  }

  @override
  State<NotificationToastOverlay> createState() =>
      _NotificationToastOverlayState();
}

class _NotificationToastOverlayState extends State<NotificationToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  String _title = '';
  String _message = '';
  String _type = 'system';
  Timer? _dismissTimer;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _showToast({
    required String title,
    required String message,
    required String type,
    required Duration autoDismissDuration,
  }) {
    _dismissTimer?.cancel();

    setState(() {
      _title = title;
      _message = message;
      _type = type;
      _isVisible = true;
    });

    unawaited(_animationController.forward());

    _dismissTimer = Timer(autoDismissDuration, _dismiss);
  }

  void _dismiss() {
    unawaited(
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      }),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'challenge_received' => AfriIcons.versus,
      'challenge_settled' => AfriIcons.rank,
      'settlement' => AfriIcons.checkGroup,
      'earn' => AfriIcons.earn,
      _ => AfriIcons.notifications,
    };
  }

  Color _colorForType(String type) {
    return switch (type) {
      'challenge_received' => ColorTokens.clubAccent,
      'challenge_settled' => ColorTokens.success,
      'settlement' => ColorTokens.success,
      'earn' => ColorTokens.clubAccent,
      _ => ColorTokens.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            top: MediaQuery.of(context).padding.top + SpacingTokens.spacing2,
            left: SpacingTokens.spacing4,
            right: SpacingTokens.spacing4,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Dismissible(
                  key: ValueKey<String>('fanzone-toast-$_title-$_message'),
                  direction: DismissDirection.up,
                  onDismissed: (_) => _dismiss(),
                  child: AfriPressFeedback(
                    onTap: _dismiss,
                    tooltip: 'Dismiss notification',
                    semanticsLabel: 'Notification: $_title. $_message',
                    semanticsHint: 'Tap or swipe up to dismiss',
                    child: Material(
                      color: ColorTokens.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorTokens.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusLg,
                          ),
                          border: BorderTokens.all(
                            color: _colorForType(_type).withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ColorTokens.ambientShadow.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(SpacingTokens.spacing4),
                        child: Row(
                          children: [
                            Container(
                              width: SpacingTokens.spacing10,
                              height: SpacingTokens.spacing10,
                              decoration: BoxDecoration(
                                color: _colorForType(
                                  _type,
                                ).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusMd,
                                ),
                              ),
                              child: Icon(
                                _iconForType(_type),
                                size: SpacingTokens.spacing5,
                                color: _colorForType(_type),
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypographyTokens.titleSmall(),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing1 / 2,
                                  ),
                                  Text(
                                    _message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypographyTokens.bodySmall(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
