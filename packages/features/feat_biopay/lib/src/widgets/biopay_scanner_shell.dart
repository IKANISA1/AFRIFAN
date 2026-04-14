import 'package:camera/camera.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../biopay_tokens.dart';
import 'biopay_reference_ui.dart';

enum BiopayScannerTone { searching, ready, blocked, error }

class BiopayScannerShell extends StatelessWidget {
  const BiopayScannerShell({
    required this.isCameraReady,
    required this.statusLabel,
    required this.helperText,
    required this.tone,
    this.controller,
    this.footer,
    this.sampleCount = 0,
    this.totalSamples = 5,
    this.isEnrollMode = true,
    super.key,
  });

  final CameraController? controller;
  final bool isCameraReady;
  final String statusLabel;
  final String helperText;
  final BiopayScannerTone tone;
  final Widget? footer;
  final int sampleCount;
  final int totalSamples;
  final bool isEnrollMode;

  Color _frameColor() {
    return switch (tone) {
      BiopayScannerTone.ready => BiopayTokens.scannerReady,
      BiopayScannerTone.error => Colors.red.shade400,
      _ => Colors.white.withValues(alpha: 0.32),
    };
  }

  @override
  Widget build(BuildContext context) {
    final helperLabel = isEnrollMode && isCameraReady
        ? 'KEEP YOUR FACE WITHIN THE OVAL'
        : '';

    return Stack(
      children: [
        Positioned.fill(
          child: isCameraReady && controller != null
              ? CameraPreview(controller!)
              : const ColoredBox(color: Colors.black),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.46),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 320,
            height: 470,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(160),
              border: BorderTokens.all(color: _frameColor(), width: 4),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 110,
          child: Center(child: BiopayReferenceStatusPill(label: statusLabel)),
        ),
        if (helperLabel.isNotEmpty)
          Positioned(
            left: 36,
            right: 36,
            bottom: MediaQuery.of(context).padding.bottom + 48,
            child: Text(
              helperLabel,
              textAlign: TextAlign.center,
              style: biopayReferenceText(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.52),
                letterSpacing: 2.6,
              ),
            ),
          ),
        if (footer != null)
          Positioned(left: 24, right: 24, bottom: 24, child: footer!),
      ],
    );
  }
}
