import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Semantic color tokens for the BioPay module.
///
/// BioPay follows the shared AFRICLUB dark runtime surfaces.
/// These tokens derive from [ColorTokens] so the module stays aligned with the
/// universal app mode instead of maintaining a second light palette.
///
/// To brand BioPay for a specific club, override [accent] and
/// [accentSecondary] at initialization time.
class BiopayTokens {
  BiopayTokens._();

  // ── Surface & Background ──

  /// Primary background matches the universal app surface.
  static Color get background => ColorTokens.background;

  /// Panel / card fill.
  static Color get panel => ColorTokens.surfaceContainer;

  /// Elevated panel used for compact controls and selected states.
  static Color get panelLight => ColorTokens.surfaceContainerHigh;

  // ── Ink & Text ──

  /// Primary text ink.
  static Color get ink => ColorTokens.onSurface;

  /// Muted / secondary text.
  static Color get muted => ColorTokens.onSurfaceVariant;

  /// Slightly darker muted for message body text.
  static Color get mutedDark =>
      ColorTokens.onSurfaceVariant.withValues(alpha: 0.92);

  /// Icon tint for secondary elements like profile button.
  static Color get iconMuted => ColorTokens.onSurfaceVariant;

  // ── Accent Colors (club-overridable) ──

  /// Primary action color — buttons, links, primary chips.
  /// Falls back to a fintech blue if club primary is too dark.
  static Color get accent => ColorTokens.clubPrimary;

  /// Secondary accent — used for NFC, alternative highlights.
  static Color get accentSecondary => ColorTokens.clubAccent;

  // ── Feature-Specific Colors ──

  /// Scanner "ready" frame highlight.
  static Color get scannerReady => ColorTokens.clubAccent;

  /// Scanner overlay accent glow (QR scan corners).
  static Color get scannerCorner => ColorTokens.clubAccent;

  /// QR code dark background for the QR display card.
  static Color get qrCardBackground => ColorTokens.surfaceDim;

  /// QR secondary text on the QR display card.
  static Color get qrSecondaryText => ColorTokens.onSurfaceVariant;

  /// Status pill background (dark translucent).
  static Color get statusPillBackground =>
      ColorTokens.surfaceContainerHigh.withValues(alpha: 0.92);

  // ── Semantic Status Colors ──

  /// Success tone — green tint panel.
  static Color get successPanel => ColorTokens.success.withValues(alpha: 0.18);

  /// Error tone — red tint panel.
  static Color get errorPanel => ColorTokens.error.withValues(alpha: 0.18);

  /// Blocked / warning tone — amber tint panel.
  static Color get blockedPanel => ColorTokens.warning.withValues(alpha: 0.18);

  /// Pending tone — blue tint panel.
  static Color get pendingPanel => ColorTokens.info.withValues(alpha: 0.18);

  /// Success accent.
  static const Color successAccent = Color(0xFF1FC34A);

  /// Error accent — used for destructive states.
  static const Color errorAccent = Color(0xFFE53935);

  /// Info / communication accent — overlay sparkle.
  static const Color infoAccent = Color(0xFF57D0FF);

  // ── Reference Feature Colors ──
  // These are used exclusively in the BioPay reference UI
  // tile grid to distinguish feature entry points.

  /// Purple — used for NFC tile.
  static const Color featurePurple = Color(0xFF4B3BFF);

  /// Orange — used for QR tile.
  static const Color featureOrange = Color(0xFFFF9800);

  /// Teal — used for "get" operations.
  static const Color featureTeal = Color(0xFF0D9B8A);
}
