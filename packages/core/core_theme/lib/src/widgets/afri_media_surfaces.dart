import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_button.dart';
import 'afri_data_display.dart';
import 'afri_governed_image.dart';
import 'afri_state_banner.dart';
import 'afri_surface_card.dart';

class AfriVideoThumbnail extends StatelessWidget {
  const AfriVideoThumbnail({
    required this.image,
    required this.width,
    required this.height,
    required this.semanticLabel,
    required this.provenanceId,
    required this.rightsApproved,
    this.state = AfriGovernedImageState.ready,
    this.durationLabel,
    this.onPlay,
    super.key,
  });

  final ImageProvider image;
  final double width;
  final double height;
  final String semanticLabel;
  final String provenanceId;
  final bool rightsApproved;
  final AfriGovernedImageState state;
  final String? durationLabel;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onPlay != null,
      image: true,
      label: [
        semanticLabel,
        if (durationLabel?.trim().isNotEmpty == true) durationLabel!.trim(),
      ].join(', '),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AfriGovernedImage(
              image: image,
              width: width,
              height: height,
              semanticLabel: semanticLabel,
              provenanceId: provenanceId,
              rightsApproved: rightsApproved,
              state: state,
              borderRadius: ShapeTokens.radiusLg,
              cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
                  .round(),
            ),
            if (rightsApproved && state == AfriGovernedImageState.ready)
              Center(
                child: AfriButton(
                  label: 'Play',
                  icon: AfriIcons.forward,
                  enabled: onPlay != null,
                  onTap: onPlay ?? () {},
                ),
              ),
            if (rightsApproved &&
                state == AfriGovernedImageState.ready &&
                durationLabel?.trim().isNotEmpty == true)
              Positioned(
                right: SpacingTokens.spacing2,
                bottom: SpacingTokens.spacing2,
                child: AfriStateBanner(
                  icon: AfriIcons.timer,
                  title: durationLabel!.trim(),
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum AfriDocumentState {
  ready,
  loading,
  error,
  empty,
  offline,
  permissionDenied,
  skeleton,
}

class AfriDocumentPreview extends StatelessWidget {
  const AfriDocumentPreview({
    required this.title,
    required this.fileType,
    required this.provenanceLabel,
    this.sizeLabel,
    this.state = AfriDocumentState.ready,
    this.onOpen,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String fileType;
  final String provenanceLabel;
  final String? sizeLabel;
  final AfriDocumentState state;
  final VoidCallback? onOpen;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        enabled && state == AfriDocumentState.ready && onOpen != null;
    return AfriSurfaceCard(
      enabled: enabled,
      onTap: canOpen ? onOpen : null,
      semanticsLabel: '$title document, $fileType',
      child: Row(
        children: [
          Icon(
            _iconFor(fileType),
            size: SizeTokens.iconHero,
            color: ColorTokens.onSurfaceVariant,
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TypographyTokens.titleMedium()),
                Text(
                  [
                    fileType.toUpperCase(),
                    if (sizeLabel?.trim().isNotEmpty == true) sizeLabel!.trim(),
                  ].join(' • '),
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Source: $provenanceLabel',
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                if (state != AfriDocumentState.ready)
                  Padding(
                    padding: const EdgeInsets.only(top: SpacingTokens.spacing2),
                    child: AfriStateBanner(
                      icon: _stateIcon(state),
                      title: _stateMessage(state),
                      tone: _stateTone(state),
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          if (canOpen) const Icon(AfriIcons.chevronRight),
        ],
      ),
    );
  }

  static IconData _iconFor(String fileType) {
    final normalized = fileType.trim().toLowerCase();
    if (normalized == 'pdf') return AfriIcons.pdf;
    if (normalized == 'xls' || normalized == 'xlsx' || normalized == 'csv') {
      return AfriIcons.excel;
    }
    return AfriIcons.article;
  }

  static IconData _stateIcon(AfriDocumentState state) => switch (state) {
    AfriDocumentState.ready => AfriIcons.statusSuccess,
    AfriDocumentState.loading => AfriIcons.statusLoading,
    AfriDocumentState.error => AfriIcons.statusError,
    AfriDocumentState.empty => AfriIcons.statusEmpty,
    AfriDocumentState.offline => AfriIcons.offline,
    AfriDocumentState.permissionDenied => AfriIcons.lock,
    AfriDocumentState.skeleton => AfriIcons.statusLoading,
  };

  static String _stateMessage(AfriDocumentState state) => switch (state) {
    AfriDocumentState.ready => 'Document ready',
    AfriDocumentState.loading => 'Loading document',
    AfriDocumentState.error => 'Document unavailable',
    AfriDocumentState.empty => 'No document available',
    AfriDocumentState.offline => 'Document unavailable offline',
    AfriDocumentState.permissionDenied => 'Permission required',
    AfriDocumentState.skeleton => 'Preparing document preview',
  };

  static AfriStateBannerTone _stateTone(AfriDocumentState state) =>
      switch (state) {
        AfriDocumentState.ready => AfriStateBannerTone.success,
        AfriDocumentState.loading ||
        AfriDocumentState.skeleton => AfriStateBannerTone.info,
        AfriDocumentState.error => AfriStateBannerTone.danger,
        AfriDocumentState.empty => AfriStateBannerTone.neutral,
        AfriDocumentState.offline ||
        AfriDocumentState.permissionDenied => AfriStateBannerTone.warning,
      };
}

/// Alias kept in the media catalog so identity and media use one fail-closed
/// implementation rather than two visually divergent avatar components.
typedef AfriMediaAvatar = AfriAvatar;

enum AfriQrBarcodeState { ready, disabled, error, empty }

class AfriQrBarcodeSurface extends StatelessWidget {
  const AfriQrBarcodeSurface({
    required this.code,
    required this.semanticLabel,
    this.helperText,
    this.sensitive = true,
    this.enabled = true,
    this.state = AfriQrBarcodeState.ready,
    super.key,
  });

  /// Caller-provided QR or barcode renderer. The shared library owns framing,
  /// privacy semantics, and disabled state; encoding stays domain-owned.
  final Widget code;
  final String semanticLabel;
  final String? helperText;
  final bool sensitive;
  final bool enabled;
  final AfriQrBarcodeState state;

  @override
  Widget build(BuildContext context) {
    final effectiveState = enabled ? state : AfriQrBarcodeState.disabled;
    final resolvedHelper = helperText?.trim().isNotEmpty == true
        ? helperText!.trim()
        : switch (effectiveState) {
            AfriQrBarcodeState.ready => null,
            AfriQrBarcodeState.disabled => 'Code is temporarily disabled',
            AfriQrBarcodeState.error => 'Code could not be generated',
            AfriQrBarcodeState.empty => 'No code is available',
          };
    return Semantics(
      container: true,
      excludeSemantics: true,
      image: true,
      enabled: effectiveState == AfriQrBarcodeState.ready,
      label: sensitive
          ? '$semanticLabel. Sensitive code; do not share'
          : semanticLabel,
      child: AfriSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: AfriComponentSizes.mediaPlaceholder,
              child: switch (effectiveState) {
                AfriQrBarcodeState.ready => ExcludeSemantics(child: code),
                AfriQrBarcodeState.disabled => Center(
                  child: Icon(
                    AfriIcons.statusBlocked,
                    size: SizeTokens.iconXxl,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
                AfriQrBarcodeState.error => Center(
                  child: Icon(
                    AfriIcons.statusError,
                    size: SizeTokens.iconXxl,
                    color: ColorTokens.error,
                  ),
                ),
                AfriQrBarcodeState.empty => Center(
                  child: Icon(
                    AfriIcons.statusEmpty,
                    size: SizeTokens.iconXxl,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
              },
            ),
            if (resolvedHelper != null) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                resolvedHelper,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
