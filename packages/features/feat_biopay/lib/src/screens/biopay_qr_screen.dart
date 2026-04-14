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

class BiopayQrScreen extends ConsumerStatefulWidget {
  const BiopayQrScreen({super.key});

  @override
  ConsumerState<BiopayQrScreen> createState() => _BiopayQrScreenState();
}

class _BiopayQrScreenState extends ConsumerState<BiopayQrScreen> {
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  PaymentRecipientType? _selectedRouteType;
  BiopayHandoffToken? _handoffToken;
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
    final validationError = validateBiopayRecipient(
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
      final normalizedRecipient = normalizeBiopayRecipient(
        routeType: selectedRouteType,
        value: _recipientController.text,
        country: _country,
      );
      final token = await ref
          .read(biopayRepositoryProvider)
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
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQr(BiopayHandoffToken token) async {
    await SharePlus.instance.share(
      ShareParams(
        text: token.resolverUrl.toString(),
        subject: 'BioPay QR code',
      ),
    );
  }

  void _formatAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = biopayReferenceFormatNumber(digits);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(biopayProfileProvider).valueOrNull;
    final selectedRouteType =
        _selectedRouteType ??
        profile?.routeType ??
        PaymentRecipientType.phoneNumber;
    final currencyCode = context.afriCurrencyCode;

    return BiopayReferencePage(
      title: 'Get QR Code',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/biopay');
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _handoffToken == null
            ? ListView(
                key: const ValueKey('form'),
                children: [
                  BiopayReferenceSegmentedControl(
                    selected: selectedRouteType,
                    onChanged: _switchRouteType,
                  ),
                  const SizedBox(height: 22),
                  BiopayReferenceValueCard(
                    label: _labelForRoute(selectedRouteType),
                    controller: _recipientController,
                    hintText: biopayRecipientHint(selectedRouteType, _country),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  BiopayReferenceValueCard(
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
                      style: biopayReferenceText(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 34),
                  BiopayReferencePrimaryButton(
                    label: _isLoading
                        ? 'Generating QR Code'
                        : 'Generate QR Code',
                    icon: Icons.qr_code_2_rounded,
                    color: BiopayTokens.qrCardBackground,
                    onTap: _isLoading ? null : _generateQr,
                  ),
                ],
              )
            : ListView(
                key: const ValueKey('qr'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: biopayReferencePanelDecoration(radius: 36),
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
                        color: BiopayTokens.panel,
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
                            Icons.bolt_rounded,
                            color: biopayReferenceBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Share QR Code',
                            style: biopayReferenceText(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: BiopayTokens.qrSecondaryText,
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
}
