import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../biopay_display_resolver.dart';
import '../biopay_tokens.dart';
import '../models/biopay_handoff_token.dart';
import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';

class BioPayQrScreen extends ConsumerStatefulWidget {
  const BioPayQrScreen({super.key});

  @override
  ConsumerState<BioPayQrScreen> createState() => _BioPayQrScreenState();
}

class _BioPayQrScreenState extends ConsumerState<BioPayQrScreen> {
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  PaymentRecipientType? _selectedRouteType;
  BioPayHandoffToken? _handoffToken;
  bool _isLoading = false;
  String? _error;

  AfriCountry get _country => AfriCountryCatalog.defaultCountry;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  int? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  void _switchRouteType(PaymentRecipientType routeType) {
    setState(() {
      _selectedRouteType = routeType;
      _error = null;
      _recipientController.clear();
    });
  }

  Future<void> _generateQr() async {
    final selectedRouteType =
        _selectedRouteType ?? PaymentRecipientType.phoneNumber;
    final validationError = validateBioPayRecipient(
      routeType: selectedRouteType,
      value: _recipientController.text,
      country: _country,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final normalizedRecipient = normalizeBioPayRecipient(
        routeType: selectedRouteType,
        value: _recipientController.text,
        country: _country,
      );
      final token = await ref
          .read(BioPayRepositoryProvider)
          .createHandoffToken(
            channel: 'qr',
            amount: _amount,
            routeType: selectedRouteType,
            recipientValue: normalizedRecipient,
            countryCode: _country.isoCode,
          );
      if (!mounted) return;
      setState(() {
        _handoffToken = token;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _userFriendlyError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQr(BioPayHandoffToken token) async {
    await SharePlus.instance.share(
      ShareParams(
        text: token.resolverUrl.toString(),
        subject: 'BioPay QR code',
      ),
    );
  }

  void _formatAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = BioPayReferenceFormatNumber(digits);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(BioPayProfileProvider).valueOrNull;
    final selectedRouteType =
        _selectedRouteType ??
        profile?.routeType ??
        PaymentRecipientType.phoneNumber;
    final currencyCode = context.afriCurrencyCode;

    return BioPayReferencePage(
      title: 'Get QR Code',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/BioPay');
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _handoffToken == null
            ? ListView(
                key: const ValueKey('form'),
                children: [
                  BioPayReferenceSegmentedControl(
                    selected: selectedRouteType,
                    onChanged: _switchRouteType,
                  ),
                  const SizedBox(height: 22),
                  BioPayReferenceValueCard(
                    label: _labelForRoute(selectedRouteType),
                    controller: _recipientController,
                    hintText: BioPayRecipientHint(selectedRouteType, _country),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  BioPayReferenceValueCard(
                    label: 'Amount (Optional)',
                    controller: _amountController,
                    prefix: currencyCode,
                    hintText: '0',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                    ],
                    onChanged: _formatAmount,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: BioPayReferenceText(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  BioPayReferencePrimaryButton(
                    label: _isLoading
                        ? 'Generating QR Code'
                        : 'Generate QR Code',
                    icon: AfriIcons.qrCode,
                    color: BioPayTokens.qrCardBackground,
                    onTap: _isLoading ? null : _generateQr,
                  ),
                ],
              )
            : ListView(
                key: const ValueKey('qr'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BioPayReferencePanelDecoration(radius: 36),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: QrImageView(
                          data: _handoffToken!.resolverUrl.toString(),
                          size: 250,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => _shareQr(_handoffToken!),
                    child: Container(
                      height: 86,
                      decoration: BoxDecoration(
                        color: BioPayTokens.panel,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: ColorTokens.ambientShadow.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AfriIcons.bolt,
                            color: BioPayReferenceBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Share QR Code',
                            style: BioPayReferenceText(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: BioPayTokens.qrSecondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _labelForRoute(PaymentRecipientType routeType) {
    return routeType == PaymentRecipientType.code
        ? 'Merchant Code'
        : 'MoMo Number';
  }

  static String _userFriendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('attestation') || raw.contains('app check')) {
      return 'Device verification failed. Restart the app and try again.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (raw.contains('socket') ||
        raw.contains('network') ||
        raw.contains('connection')) {
      return 'Network error. Check your internet connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
