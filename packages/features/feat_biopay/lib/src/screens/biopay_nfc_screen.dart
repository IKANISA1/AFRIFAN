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

class BiopayNfcScreen extends ConsumerStatefulWidget {
  const BiopayNfcScreen({super.key});

  @override
  ConsumerState<BiopayNfcScreen> createState() => _BiopayNfcScreenState();
}

class _BiopayNfcScreenState extends ConsumerState<BiopayNfcScreen> {
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
    await BiopayNfcService.checkAvailability();
    final hceService = ref.read(biopayNfcHceServiceProvider);
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
      _isBusy = true;
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
            channel: 'nfc',
            amount: _amount,
            routeType: selectedRouteType,
            recipientValue: normalizedRecipient,
            countryCode: _country.isoCode,
          );

      if (_supportsHce) {
        await ref
            .read(biopayNfcHceServiceProvider)
            .startPaymentRequest(uri: token.resolverUrl);
      } else if (BiopayNfcService.canWrite) {
        await BiopayNfcService.writeUri(token.resolverUrl);
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
        _error = error.toString();
        _isBusy = false;
      });
    }
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
      title: 'NFC Payment',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/biopay');
        }
      },
      child: ListView(
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
}
