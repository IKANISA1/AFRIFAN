import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Duration afriRouteTransitionDuration = Duration(milliseconds: 220);
const Duration afriRouteReverseTransitionDuration = Duration(milliseconds: 170);

/// Shared pushed-route transition for AFRICLUB mobile routes.
///
/// Tab switching remains owned by [StatefulShellRoute.indexedStack]. Use this
/// for detail and settings-style pushed routes that should feel consistent
/// across feature packages.
Page<T> afriRoutePage<T>(
  GoRouterState state,
  Widget child, {
  bool fullscreenDialog = false,
  Duration transitionDuration = afriRouteTransitionDuration,
  Duration reverseTransitionDuration = afriRouteReverseTransitionDuration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (reduceMotion) {
        return child;
      }

      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Shared modal-sheet page for secondary routes that must remain deep-linkable.
///
/// Use this for short detail, settings, commerce, and utility surfaces. The
/// URL remains stable for app links and notifications, while the product
/// experience stays anchored in the parent hub instead of becoming another
/// full-screen destination.
Page<T> afriSheetPage<T>(
  GoRouterState state,
  Widget child, {
  double heightFactor = 0.9,
  bool fullHeight = false,
  Duration transitionDuration = afriRouteTransitionDuration,
  Duration reverseTransitionDuration = afriRouteReverseTransitionDuration,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    opaque: false,
    barrierDismissible: true,
    barrierColor: ColorTokens.scrim.withValues(alpha: 0.62),
    barrierLabel: 'Close',
    fullscreenDialog: true,
    transitionDuration: transitionDuration,
    reverseTransitionDuration: reverseTransitionDuration,
    child: _AfriRouteSheet(
      heightFactor: fullHeight ? 0.98 : heightFactor,
      child: child,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (reduceMotion) {
        return child;
      }

      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AfriRouteSheet extends StatelessWidget {
  const _AfriRouteSheet({required this.heightFactor, required this.child});

  final double heightFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: heightFactor.clamp(0.35, 0.98),
        widthFactor: 1,
        child: AfriBottomSheet(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ShapeTokens.radiusXl),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
