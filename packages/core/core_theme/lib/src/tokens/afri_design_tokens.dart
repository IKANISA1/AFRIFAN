import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'motion_tokens.dart';
import 'shape_tokens.dart';
import 'spacing_tokens.dart';
import 'tap_tokens.dart';

/// Runtime implementation of the non-color token families in root DESIGN.md.
///
/// The values here are semantic implementation tokens. They are not a second
/// design authority; they encode the mandatory responsive, motion, focus,
/// and admin contracts from the repository-level DESIGN.md.
class AfriDesignTokens extends ThemeExtension<AfriDesignTokens> {
  const AfriDesignTokens({
    required this.spaceStep,
    required this.compactPhoneMaxWidth,
    required this.standardPhoneMaxWidth,
    required this.largePhoneMaxWidth,
    required this.smallTabletMaxWidth,
    required this.expandedMinWidth,
    required this.minTouchTarget,
    required this.minDenseIconTarget,
    required this.comfortableTouchTarget,
    required this.cardRadius,
    required this.panelRadius,
    required this.sheetRadius,
    required this.pillRadius,
    required this.fastMotion,
    required this.standardMotion,
    required this.slowMotion,
    required this.reducedMotion,
    required this.focusRingWidth,
    required this.focusRingGap,
    required this.focusScale,
    required this.adminRailWidth,
    required this.adminCompactRailWidth,
    required this.adminTableRowHeight,
    required this.adminDetailPanelWidth,
    required this.adminCompactFallbackMaxWidth,
  });

  factory AfriDesignTokens.standard() => const AfriDesignTokens(
    spaceStep: 4,
    compactPhoneMaxWidth: 374,
    standardPhoneMaxWidth: 430,
    largePhoneMaxWidth: 599,
    smallTabletMaxWidth: 719,
    expandedMinWidth: 720,
    minTouchTarget: AfriTapTargets.minimum,
    minDenseIconTarget: 44,
    comfortableTouchTarget: AfriTapTargets.comfortable,
    cardRadius: ShapeTokens.radiusSm,
    panelRadius: ShapeTokens.radiusSm,
    sheetRadius: ShapeTokens.radiusXl,
    pillRadius: ShapeTokens.radiusFull,
    fastMotion: AfriMotion.quick,
    standardMotion: AfriMotion.standard,
    slowMotion: AfriMotion.emphasized,
    reducedMotion: Duration(milliseconds: 1),
    focusRingWidth: 3,
    focusRingGap: 2,
    focusScale: 1.02,
    adminRailWidth: 280,
    adminCompactRailWidth: 72,
    adminTableRowHeight: 56,
    adminDetailPanelWidth: 420,
    adminCompactFallbackMaxWidth: 719,
  );

  factory AfriDesignTokens.highContrast() {
    final base = AfriDesignTokens.standard();
    return base.copyWith(focusRingWidth: 4, focusRingGap: 3);
  }

  factory AfriDesignTokens.reducedMotion() {
    final base = AfriDesignTokens.standard();
    return base.copyWith(
      fastMotion: base.reducedMotion,
      standardMotion: base.reducedMotion,
      slowMotion: base.reducedMotion,
      focusScale: 1,
    );
  }

  final double spaceStep;

  final double compactPhoneMaxWidth;
  final double standardPhoneMaxWidth;
  final double largePhoneMaxWidth;
  final double smallTabletMaxWidth;
  final double expandedMinWidth;

  final double minTouchTarget;
  final double minDenseIconTarget;
  final double comfortableTouchTarget;

  final double cardRadius;
  final double panelRadius;
  final double sheetRadius;
  final double pillRadius;

  final Duration fastMotion;
  final Duration standardMotion;
  final Duration slowMotion;
  final Duration reducedMotion;

  final double focusRingWidth;
  final double focusRingGap;
  final double focusScale;

  final double adminRailWidth;
  final double adminCompactRailWidth;
  final double adminTableRowHeight;
  final double adminDetailPanelWidth;
  final double adminCompactFallbackMaxWidth;

  static const List<String> requiredStateIds = <String>[
    'loading',
    'empty',
    'error',
    'offline',
    'permissionDenied',
    'disabled',
    'focused',
    'pressed',
    'selected',
    'largeText',
    'reducedMotion',
    'darkMode',
    'lightMode',
    'syncing',
    'conflict',
    'securityTimeout',
  ];

  static const List<String> requiredMobileViewportIds = <String>[
    'compactPhone320To374',
    'standardPhone375To430',
    'largePhone431To599',
    'smallTablet600To719',
    'expanded720Plus',
    'landscape',
    'keyboardOpen',
  ];

  static const List<String> requiredAdminEvidenceIds = <String>[
    'desktop',
    'tablet',
    'compactFallback',
    'denseTable',
    'cardListFallback',
    'filterOpen',
    'detailPanel',
    'bulkSelection',
    'permissionDenied',
    'staleData',
    'highVolume',
  ];

  AfriViewportBand viewportBandForWidth(double width) {
    if (width <= compactPhoneMaxWidth) return AfriViewportBand.compactPhone;
    if (width <= standardPhoneMaxWidth) return AfriViewportBand.standardPhone;
    if (width <= largePhoneMaxWidth) return AfriViewportBand.largePhone;
    if (width <= smallTabletMaxWidth) return AfriViewportBand.smallTablet;
    return AfriViewportBand.expanded;
  }

  EdgeInsets screenPaddingForWidth(double width) {
    return switch (viewportBandForWidth(width)) {
      AfriViewportBand.compactPhone => const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing4,
      ),
      AfriViewportBand.standardPhone => const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing5,
        vertical: SpacingTokens.spacing4,
      ),
      AfriViewportBand.largePhone => const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing6,
        vertical: SpacingTokens.spacing5,
      ),
      AfriViewportBand.smallTablet => const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing6,
        vertical: SpacingTokens.spacing6,
      ),
      AfriViewportBand.expanded => const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing8,
        vertical: SpacingTokens.spacing6,
      ),
    };
  }

  Duration motionFor({
    required bool reducedMotionEnabled,
    required AfriMotionRole role,
  }) {
    if (reducedMotionEnabled) return reducedMotion;
    return switch (role) {
      AfriMotionRole.fast => fastMotion,
      AfriMotionRole.standard => standardMotion,
      AfriMotionRole.slow => slowMotion,
    };
  }

  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);
  BorderRadius get panelBorderRadius => BorderRadius.circular(panelRadius);
  BorderRadius get sheetBorderRadius =>
      BorderRadius.vertical(top: Radius.circular(sheetRadius));
  BorderRadius get pillBorderRadius => BorderRadius.circular(pillRadius);

  @override
  AfriDesignTokens copyWith({
    double? spaceStep,
    double? compactPhoneMaxWidth,
    double? standardPhoneMaxWidth,
    double? largePhoneMaxWidth,
    double? smallTabletMaxWidth,
    double? expandedMinWidth,
    double? minTouchTarget,
    double? minDenseIconTarget,
    double? comfortableTouchTarget,
    double? cardRadius,
    double? panelRadius,
    double? sheetRadius,
    double? pillRadius,
    Duration? fastMotion,
    Duration? standardMotion,
    Duration? slowMotion,
    Duration? reducedMotion,
    double? focusRingWidth,
    double? focusRingGap,
    double? focusScale,
    double? adminRailWidth,
    double? adminCompactRailWidth,
    double? adminTableRowHeight,
    double? adminDetailPanelWidth,
    double? adminCompactFallbackMaxWidth,
  }) {
    return AfriDesignTokens(
      spaceStep: spaceStep ?? this.spaceStep,
      compactPhoneMaxWidth: compactPhoneMaxWidth ?? this.compactPhoneMaxWidth,
      standardPhoneMaxWidth:
          standardPhoneMaxWidth ?? this.standardPhoneMaxWidth,
      largePhoneMaxWidth: largePhoneMaxWidth ?? this.largePhoneMaxWidth,
      smallTabletMaxWidth: smallTabletMaxWidth ?? this.smallTabletMaxWidth,
      expandedMinWidth: expandedMinWidth ?? this.expandedMinWidth,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
      minDenseIconTarget: minDenseIconTarget ?? this.minDenseIconTarget,
      comfortableTouchTarget:
          comfortableTouchTarget ?? this.comfortableTouchTarget,
      cardRadius: cardRadius ?? this.cardRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      fastMotion: fastMotion ?? this.fastMotion,
      standardMotion: standardMotion ?? this.standardMotion,
      slowMotion: slowMotion ?? this.slowMotion,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
      focusRingGap: focusRingGap ?? this.focusRingGap,
      focusScale: focusScale ?? this.focusScale,
      adminRailWidth: adminRailWidth ?? this.adminRailWidth,
      adminCompactRailWidth:
          adminCompactRailWidth ?? this.adminCompactRailWidth,
      adminTableRowHeight: adminTableRowHeight ?? this.adminTableRowHeight,
      adminDetailPanelWidth:
          adminDetailPanelWidth ?? this.adminDetailPanelWidth,
      adminCompactFallbackMaxWidth:
          adminCompactFallbackMaxWidth ?? this.adminCompactFallbackMaxWidth,
    );
  }

  @override
  AfriDesignTokens lerp(AfriDesignTokens? other, double t) {
    if (other is! AfriDesignTokens) return this;

    return AfriDesignTokens(
      spaceStep: _lerp(spaceStep, other.spaceStep, t),
      compactPhoneMaxWidth: _lerp(
        compactPhoneMaxWidth,
        other.compactPhoneMaxWidth,
        t,
      ),
      standardPhoneMaxWidth: _lerp(
        standardPhoneMaxWidth,
        other.standardPhoneMaxWidth,
        t,
      ),
      largePhoneMaxWidth: _lerp(
        largePhoneMaxWidth,
        other.largePhoneMaxWidth,
        t,
      ),
      smallTabletMaxWidth: _lerp(
        smallTabletMaxWidth,
        other.smallTabletMaxWidth,
        t,
      ),
      expandedMinWidth: _lerp(expandedMinWidth, other.expandedMinWidth, t),
      minTouchTarget: _lerp(minTouchTarget, other.minTouchTarget, t),
      minDenseIconTarget: _lerp(
        minDenseIconTarget,
        other.minDenseIconTarget,
        t,
      ),
      comfortableTouchTarget: _lerp(
        comfortableTouchTarget,
        other.comfortableTouchTarget,
        t,
      ),
      cardRadius: _lerp(cardRadius, other.cardRadius, t),
      panelRadius: _lerp(panelRadius, other.panelRadius, t),
      sheetRadius: _lerp(sheetRadius, other.sheetRadius, t),
      pillRadius: _lerp(pillRadius, other.pillRadius, t),
      fastMotion: _lerpDuration(fastMotion, other.fastMotion, t),
      standardMotion: _lerpDuration(standardMotion, other.standardMotion, t),
      slowMotion: _lerpDuration(slowMotion, other.slowMotion, t),
      reducedMotion: _lerpDuration(reducedMotion, other.reducedMotion, t),
      focusRingWidth: _lerp(focusRingWidth, other.focusRingWidth, t),
      focusRingGap: _lerp(focusRingGap, other.focusRingGap, t),
      focusScale: _lerp(focusScale, other.focusScale, t),
      adminRailWidth: _lerp(adminRailWidth, other.adminRailWidth, t),
      adminCompactRailWidth: _lerp(
        adminCompactRailWidth,
        other.adminCompactRailWidth,
        t,
      ),
      adminTableRowHeight: _lerp(
        adminTableRowHeight,
        other.adminTableRowHeight,
        t,
      ),
      adminDetailPanelWidth: _lerp(
        adminDetailPanelWidth,
        other.adminDetailPanelWidth,
        t,
      ),
      adminCompactFallbackMaxWidth: _lerp(
        adminCompactFallbackMaxWidth,
        other.adminCompactFallbackMaxWidth,
        t,
      ),
    );
  }

  static double _lerp(double a, double b, double t) => lerpDouble(a, b, t)!;

  static Duration _lerpDuration(Duration a, Duration b, double t) {
    final micros = _lerp(
      a.inMicroseconds.toDouble(),
      b.inMicroseconds.toDouble(),
      t,
    ).round();
    return Duration(microseconds: micros);
  }
}

enum AfriViewportBand {
  compactPhone,
  standardPhone,
  largePhone,
  smallTablet,
  expanded,
}

enum AfriMotionRole { fast, standard, slow }
