import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_handoff_resolution.dart';
import '../models/biopay_payment_review_args.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_nfc_service.dart';
import '../widgets/biopay_branding.dart';

/// BioPay NFC — segmented mode + amount input + CTA.
class BiopayNfcScreen extends ConsumerStatefulWidget {
  const BiopayNfcScreen({super.key});

  @override
  ConsumerState<BiopayNfcScreen> createState() => _BiopayNfcScreenState();
}

class _BiopayNfcScreenState extends ConsumerState<BiopayNfcScreen> {
  bool _supportsHce = false;
  bool _isBusy = false;
  bool _isReceiveArmed = false;
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
        _isReceiveArmed = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isBusy = false;
        _isReceiveArmed = false;
      });
    }
  }

  Future<void> _stopReceiveMode() async {
    try {
      if (_supportsHce) {
        await ref.read(biopayNfcHceServiceProvider).stopPaymentRequest();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isReceiveArmed = false);
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
    final appName = biopayAppName(context);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('NFC Payment', style: TypographyTokens.titleLarge()),
      ),
      body: BiopayMoodBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: SpacingTokens.spacing6),

                BiopayHeroCard(
                  eyebrow: 'CONTACTLESS • $appName',
                  title: _isReceiveMode
                      ? (_isReceiveArmed
                            ? 'Ready for a tap'
                            : 'Share a live NFC request')
                      : 'Scan an NFC BioPay request',
                  subtitle: _isReceiveMode
                      ? (_isReceiveArmed
                            ? 'Hold your device near the other supporter phone to hand off this payment request.'
                            : 'Arm this phone as the receiving side, then let the payer tap to launch their transfer.')
                      : 'Use this when another member presents an AFRICLUB BioPay NFC request.',
                  bottom: Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: [
                      BiopayBadge(
                        icon: _supportsHce
                            ? Icons.contactless_rounded
                            : Icons.nfc_rounded,
                        label: _supportsHce ? 'HCE Ready' : 'Tag Write Mode',
                        tint: primaryColor.withValues(alpha: 0.14),
                      ),
                      if (_isReceiveMode && _presetAmount != null)
                        BiopayBadge(
                          icon: Icons.sell_outlined,
                          label: '${currencyCode ?? 'RWF'} $_presetAmount',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: SpacingTokens.spacing6),

                _ModeSegment(
                  isReceive: _isReceiveMode,
                  onChanged: (v) async {
                    if (_isReceiveArmed && !v) {
                      await _stopReceiveMode();
                    }
                    setState(() => _isReceiveMode = v);
                  },
                  primaryColor: primaryColor,
                ),

                const SizedBox(height: SpacingTokens.spacing8),

                if (_isReceiveMode) ...[
                  if (_isReceiveArmed)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _NfcPulse(primaryColor: primaryColor),
                            const SizedBox(height: SpacingTokens.spacing6),
                            Text(
                              'Tap to Pay',
                              style: TypographyTokens.displaySmall(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              'Keep this screen open while the other supporter taps.',
                              style: TypographyTokens.bodyMedium().copyWith(
                                color: ColorTokens.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
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
                              onChanged: (v) => setState(() {
                                _presetAmount = int.tryParse(v);
                              }),
                              style: TypographyTokens.displaySmall().copyWith(
                                fontSize: 28,
                              ),
                              decoration: InputDecoration.collapsed(
                                hintText: '0',
                                hintStyle: TypographyTokens.displaySmall()
                                    .copyWith(
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
                ] else ...[
                  ClayCard(
                    backgroundColor: ColorTokens.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(32),
                    padding: const EdgeInsets.all(SpacingTokens.spacing5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.contactless_rounded,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: SpacingTokens.spacing4),
                        Expanded(
                          child: Text(
                            'Bring the other phone or NFC tag close to resolve its BioPay request and continue to review.',
                            style: TypographyTokens.bodyMedium().copyWith(
                              color: ColorTokens.onSurfaceVariant,
                              height: 1.4,
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
                      ? (_isReceiveArmed ? 'Stop NFC Request' : 'Activate NFC')
                      : 'Scan NFC',
                  onPressed: _isBusy
                      ? null
                      : (_isReceiveMode
                            ? (_isReceiveArmed
                                  ? _stopReceiveMode
                                  : _activateReceiveMode)
                            : _scanRequest),
                  isLoading: _isBusy,
                  icon: _isReceiveMode
                      ? Icons.nfc_rounded
                      : Icons.contactless_rounded,
                  width: double.infinity,
                  preserveCase: true,
                  letterSpacing: 0.6,
                ),

                const SizedBox(height: SpacingTokens.spacing8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NfcPulse extends StatelessWidget {
  const _NfcPulse({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final scale in [1.05, 1.35, 1.7])
            Container(
              width: 120 * scale,
              height: 120 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.12 / scale),
                ),
              ),
            ),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.22),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.contactless_rounded,
              size: 60,
              color: primaryColor,
            ),
          ),
        ],
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
      height: 48,
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Receive',
            isSelected: isReceive,
            primaryColor: primaryColor,
            onTap: () => onChanged(true),
          ),
          _Tab(
            label: 'Scan',
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
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TypographyTokens.labelLarge().copyWith(
              fontWeight: FontWeight.w700,
              color: isSelected ? primaryColor : ColorTokens.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
