import 'dart:async';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/biopay_handoff_token.dart';
import '../providers/biopay_providers.dart';

/// BioPay QR — two-state screen: form → QR display.
class BiopayQrScreen extends ConsumerStatefulWidget {
  const BiopayQrScreen({super.key});

  @override
  ConsumerState<BiopayQrScreen> createState() => _BiopayQrScreenState();
}

class _BiopayQrScreenState extends ConsumerState<BiopayQrScreen> {
  static const _refreshSeconds = 60;

  Timer? _timer;
  int _secondsRemaining = _refreshSeconds;
  int? _presetAmount;
  BiopayHandoffToken? _handoffToken;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = _refreshSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        _generateQr();
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  Future<void> _generateQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(biopayRepositoryProvider)
          .createHandoffToken(channel: 'qr', amount: _presetAmount);
      if (!mounted) return;
      setState(() {
        _handoffToken = token;
        _isLoading = false;
      });
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQr(BiopayHandoffToken token) async {
    await SharePlus.instance.share(
      ShareParams(
        text: token.resolverUrl.toString(),
        subject: 'BioPay payment request',
      ),
    );
  }

  Future<void> _saveQrToPhotos(BiopayHandoffToken token) async {
    try {
      final painter = QrPainter(
        data: token.resolverUrl.toString(),
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: ColorTokens.background,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: ColorTokens.background,
        ),
      );
      final bytes = await painter.toImageData(
        1080,
        format: ui.ImageByteFormat.png,
      );
      final pngBytes = bytes?.buffer.asUint8List();
      if (pngBytes == null || pngBytes.isEmpty) return;

      await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(pngBytes),
        name: 'biopay_qr_${DateTime.now().millisecondsSinceEpoch}',
        quality: 100,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR saved to photos.')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final profile = ref.watch(biopayProfileProvider);
    final currencyCode = profile.valueOrNull?.country.currencyCode;
    final hasQr = _handoffToken != null && !_isLoading;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Get QR Code', style: TypographyTokens.titleLarge()),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),

              // FORM STATE or QR DISPLAY STATE
              if (hasQr)
                _QrDisplayState(
                  token: _handoffToken!,
                  secondsRemaining: _secondsRemaining,
                  onShare: () => _shareQr(_handoffToken!),
                  onSave: () => _saveQrToPhotos(_handoffToken!),
                )
              else ...[
                // Amount
                Text(
                  'Amount (Optional)',
                  style: TypographyTokens.labelSmall().copyWith(
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                ClayCard(
                  backgroundColor: ColorTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing5,
                    vertical: SpacingTokens.spacing4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        currencyCode ?? 'RWF',
                        style: TypographyTokens.headlineSmall().copyWith(
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) =>
                              setState(() => _presetAmount = int.tryParse(v)),
                          style: TypographyTokens.displaySmall().copyWith(
                            fontSize: 28,
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: '0',
                            hintStyle: TypographyTokens.displaySmall().copyWith(
                              fontSize: 28,
                              color: ColorTokens.onSurfaceVariant.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    _error!,
                    style: TypographyTokens.bodySmall().copyWith(
                      color: ColorTokens.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],

              const Spacer(flex: 2),

              // CTA
              if (!hasQr)
                ClaymorphicButton(
                  label: _isLoading ? 'Generating...' : 'Generate QR Code',
                  onPressed: _isLoading ? null : _generateQr,
                  isLoading: _isLoading,
                  icon: Icons.qr_code_2_rounded,
                  width: double.infinity,
                  preserveCase: true,
                  letterSpacing: 0.6,
                ),

              if (hasQr)
                ClaymorphicButton(
                  label: 'Share QR Code',
                  onPressed: () => _shareQr(_handoffToken!),
                  icon: Icons.bolt_rounded,
                  width: double.infinity,
                  preserveCase: true,
                  letterSpacing: 0.6,
                ),

              const SizedBox(height: SpacingTokens.spacing8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── QR Display State ──

class _QrDisplayState extends StatelessWidget {
  const _QrDisplayState({
    required this.token,
    required this.secondsRemaining,
    required this.onShare,
    required this.onSave,
  });

  final BiopayHandoffToken token;
  final int secondsRemaining;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClayCard(
        backgroundColor: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(40),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Container(
          width: 252,
          height: 252,
          padding: const EdgeInsets.all(SpacingTokens.spacing5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: ColorTokens.surfaceContainerHighest,
              width: 2,
            ),
          ),
          child: QrImageView(
            data: token.resolverUrl.toString(),
            version: QrVersions.auto,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
