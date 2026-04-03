import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_handoff_resolution.dart';
import '../models/biopay_payment_review_args.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_nfc_service.dart';

/// BioPay NFC — segmented mode + amount input + CTA.
class BiopayNfcScreen extends ConsumerStatefulWidget {
  const BiopayNfcScreen({super.key});

  @override
  ConsumerState<BiopayNfcScreen> createState() => _BiopayNfcScreenState();
}

class _BiopayNfcScreenState extends ConsumerState<BiopayNfcScreen> {
  bool _supportsHce = false;
  bool _isBusy = false;
  int? _presetAmount;
  String? _error;

  // Mode: true = receive, false = scan
  bool _isReceiveMode = true;

  @override
  void initState() {
    super.initState();
    _refreshCapabilities();
  }

  Future<void> _refreshCapabilities() async {
    await BiopayNfcService.checkAvailability();
    final hceService = ref.read(biopayNfcHceServiceProvider);
    final supportsHce = await hceService.isSupported();

    if (!mounted) return;
    setState(() {
      _supportsHce = supportsHce;
    });
  }

  Future<void> _activateReceiveMode() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(biopayRepositoryProvider)
          .createHandoffToken(channel: 'nfc', amount: _presetAmount);

      if (_supportsHce) {
        await ref
            .read(biopayNfcHceServiceProvider)
            .startPaymentRequest(uri: token.resolverUrl);
      } else if (BiopayNfcService.canWrite) {
        await BiopayNfcService.writeUri(token.resolverUrl);
      } else {
        throw StateError('Receive mode unavailable on this device.');
      }

      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isBusy = false;
      });
    }
  }

  Future<void> _scanRequest() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final result = await BiopayNfcService.readTag();
      final raw = result.uri?.toString() ?? result.rawText ?? '';
      final token = BiopayHandoffResolution.extractToken(raw);
      if (token == null) {
        throw StateError('No BioPay request found.');
      }
      final resolution = await ref
          .read(biopayRepositoryProvider)
          .resolveHandoffToken(token: token);
      if (!mounted) return;
      setState(() => _isBusy = false);
      context.push(
        '/biopay/review',
        extra: BiopayPaymentReviewArgs.handoff(
          source: BiopayReviewSource.nfcScan,
          handoffResolution: resolution,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final profile = ref.watch(biopayProfileProvider);
    final currencyCode = profile.valueOrNull?.country.currencyCode;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('NFC PAYMENT', style: TypographyTokens.headlineLarge()),
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
              const SizedBox(height: SpacingTokens.spacing6),

              // Mode segmented
              _ModeSegment(
                isReceive: _isReceiveMode,
                onChanged: (v) => setState(() => _isReceiveMode = v),
                primaryColor: primaryColor,
              ),

              const SizedBox(height: SpacingTokens.spacing8),

              if (_isReceiveMode) ...[
                // Amount field
                Text(
                  'AMOUNT (OPTIONAL)',
                  style: TypographyTokens.labelSmall().copyWith(
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                GlassCard(
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
                          onChanged: (v) => setState(() {
                            _presetAmount = int.tryParse(v);
                          }),
                          style: TypographyTokens.displaySmall().copyWith(
                            fontSize: 28,
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: '0',
                            hintStyle: TypographyTokens.displaySmall().copyWith(
                              fontSize: 28,
                              color: ColorTokens.onSurfaceVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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

              const Spacer(),

              // CTA
              ClaymorphicButton(
                label: _isBusy
                    ? 'Working...'
                    : _isReceiveMode
                        ? 'Activate NFC'
                        : 'Scan NFC',
                onPressed: _isBusy ? null : (_isReceiveMode ? _activateReceiveMode : _scanRequest),
                isLoading: _isBusy,
                icon: _isReceiveMode ? Icons.nfc_rounded : Icons.contactless_rounded,
                width: double.infinity,
              ),

              const SizedBox(height: SpacingTokens.spacing8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mode Segment ──

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.isReceive,
    required this.onChanged,
    required this.primaryColor,
  });

  final bool isReceive;
  final ValueChanged<bool> onChanged;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'RECEIVE',
            isSelected: isReceive,
            primaryColor: primaryColor,
            onTap: () => onChanged(true),
          ),
          _Tab(
            label: 'SCAN',
            isSelected: !isReceive,
            primaryColor: primaryColor,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: AfriMotion.quick,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TypographyTokens.labelMedium().copyWith(
              fontWeight: FontWeight.w700,
              color: isSelected ? primaryColor : ColorTokens.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
