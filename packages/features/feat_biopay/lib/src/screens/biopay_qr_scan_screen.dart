import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/biopay_handoff_resolution.dart';
import '../models/biopay_payment_review_args.dart';
import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';

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
  String _statusLabel = 'Searching...';

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
      _statusLabel = 'QR Detected';
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _statusLabel = 'Scan failed';
      });
      await _controller.start();
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted && !_isResolving) {
          setState(() => _statusLabel = 'Searching...');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(color: Colors.black.withValues(alpha: 0.24)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 28,
            child: BiopayReferenceDarkBackButton(
              onTap: () => context.go('/biopay'),
            ),
          ),
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: BorderTokens.all(
                          color: const Color(0xFFFFCD08),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  const _QrCorner(alignment: Alignment.topLeft),
                  const _QrCorner(alignment: Alignment.topRight),
                  const _QrCorner(alignment: Alignment.bottomLeft),
                  const _QrCorner(alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 96,
            child: Center(
              child: BiopayReferenceStatusPill(label: _statusLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCorner extends StatelessWidget {
  const _QrCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isTop && isLeft ? 18 : 0),
            topRight: Radius.circular(isTop && !isLeft ? 18 : 0),
            bottomLeft: Radius.circular(!isTop && isLeft ? 18 : 0),
            bottomRight: Radius.circular(!isTop && !isLeft ? 18 : 0),
          ),
          border: Border(
            top: BorderTokens.side(
              color: isTop ? const Color(0xFFFFCD08) : Colors.transparent,
              width: 4,
            ),
            bottom: BorderTokens.side(
              color: !isTop ? const Color(0xFFFFCD08) : Colors.transparent,
              width: 4,
            ),
            left: BorderTokens.side(
              color: isLeft ? const Color(0xFFFFCD08) : Colors.transparent,
              width: 4,
            ),
            right: BorderTokens.side(
              color: !isLeft ? const Color(0xFFFFCD08) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
      ),
    );
  }
}
