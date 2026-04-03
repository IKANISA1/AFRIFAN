import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/biopay_handoff_resolution.dart';
import '../models/biopay_payment_review_args.dart';
import '../providers/biopay_providers.dart';

/// BioPay QR Scan — full-screen camera scanner with GlassCard status bar.
class BiopayQrScanScreen extends ConsumerStatefulWidget {
  const BiopayQrScanScreen({super.key});

  @override
  ConsumerState<BiopayQrScanScreen> createState() => _BiopayQrScanScreenState();
}

class _BiopayQrScanScreenState extends ConsumerState<BiopayQrScanScreen> {
  late final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    autoZoom: true,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
    cameraResolution: const Size(1920, 1080),
  );

  bool _isResolving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isResolving) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    await _controller.stop();
    setState(() {
      _isResolving = true;
      _error = null;
    });

    try {
      final token = BiopayHandoffResolution.extractToken(raw);
      if (token == null) {
        throw StateError('Not a valid BioPay QR.');
      }
      final resolution = await ref
          .read(biopayRepositoryProvider)
          .resolveHandoffToken(token: token);

      if (!mounted) return;
      context.pushReplacement(
        '/biopay/review',
        extra: BiopayPaymentReviewArgs.handoff(
          source: BiopayReviewSource.qrScan,
          handoffResolution: resolution,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isResolving = false;
      });
    }
  }

  Future<void> _restartScanner() async {
    setState(() {
      _error = null;
      _isResolving = false;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // ── Scan frame ──
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ColorTokens.ghostBorder,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),

          // ── Back button ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ColorTokens.glassFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: ColorTokens.ghostBorder),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // ── Status / error bar ──
          if (_isResolving || _error != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: SpacingTokens.spacing6,
              right: SpacingTokens.spacing6,
              child: GlassCard(
                animate: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isResolving ? 'Verifying...' : 'Scan failed',
                      style: TypographyTokens.titleMedium(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: SpacingTokens.spacing2),
                      GestureDetector(
                        onTap: _restartScanner,
                        child: Text(
                          'Tap to retry',
                          style: TypographyTokens.bodySmall().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
