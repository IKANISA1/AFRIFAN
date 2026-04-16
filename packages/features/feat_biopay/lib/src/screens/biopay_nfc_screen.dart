import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../biopay_display_resolver.dart';
import '../providers/biopay_providers.dart';
import '../services/biopay_nfc_service.dart';
import '../widgets/biopay_reference_ui.dart';

class BioPayNfcScreen extends ConsumerStatefulWidget {
  const BioPayNfcScreen({super.key});

  @override
  ConsumerState<BioPayNfcScreen> createState() => _BioPayNfcScreenState();
}

class _BioPayNfcScreenState extends ConsumerState<BioPayNfcScreen> {
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  PaymentRecipientType? _selectedRouteType;
  bool _supportsHce = false;
  bool _isBusy = false;
  String? _error;

  AfriCountry get _country => AfriCountryCatalog.defaultCountry;

  int? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  @override
  void initState() {
    super.initState();
    _refreshCapabilities();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _refreshCapabilities() async {
    await BioPayNfcService.checkAvailability();
    final hceService = ref.read(BioPayNfcHceServiceProvider);
    final supportsHce = await hceService.isSupported();
    if (!mounted) return;
    setState(() => _supportsHce = supportsHce);
  }

  void _switchRouteType(PaymentRecipientType routeType) {
    setState(() {
      _selectedRouteType = routeType;
      _error = null;
      _recipientController.clear();
    });
  }

  Future<void> _activateNfc() async {
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
      _isBusy = true;
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
            channel: 'nfc',
            amount: _amount,
            routeType: selectedRouteType,
            recipientValue: normalizedRecipient,
            countryCode: _country.isoCode,
          );

      if (_supportsHce) {
        await ref
            .read(BioPayNfcHceServiceProvider)
            .startPaymentRequest(uri: token.resolverUrl);
      } else if (BioPayNfcService.canWrite) {
        await BioPayNfcService.writeUri(token.resolverUrl);
      } else {
        throw StateError('NFC is unavailable on this device.');
      }

      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC request is ready for a tap.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _userFriendlyError(error);
        _isBusy = false;
      });
    }
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
      title: 'NFC Payment',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/BioPay');
        }
      },
      child: ListView(
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
            label: _isBusy ? 'Activating NFC' : 'Activate NFC',
            icon: Icons.nfc_rounded,
            onTap: _isBusy ? null : _activateNfc,
          ),
        ],
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
    if (raw.contains('nfc') && raw.contains('unavailable')) {
      return 'NFC is not available on this device.';
    }
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
