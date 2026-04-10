import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/biopay_handoff_token.dart';
import '../models/biopay_profile.dart';
import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';

class BiopayQrScreen extends ConsumerStatefulWidget {
  const BiopayQrScreen({super.key});

  @override
  ConsumerState<BiopayQrScreen> createState() => _BiopayQrScreenState();
}

class _BiopayQrScreenState extends ConsumerState<BiopayQrScreen> {
  final _amountController = TextEditingController();
  PaymentRecipientType? _selectedRouteType;
  BiopayHandoffToken? _handoffToken;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _generateQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await ref
          .read(biopayRepositoryProvider)
          .createHandoffToken(channel: 'qr', amount: _amount);
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
    final user = ref.watch(currentUserProvider);
    final selectedRouteType =
        _selectedRouteType ??
        profile?.routeType ??
        PaymentRecipientType.phoneNumber;

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
                    onChanged: (value) =>
                        setState(() => _selectedRouteType = value),
                  ),
                  const SizedBox(height: 22),
                  BiopayReferenceValueCard(
                    label: _labelForRoute(selectedRouteType),
                    value: _valueForRoute(selectedRouteType, profile, user),
                  ),
                  const SizedBox(height: 22),
                  BiopayReferenceValueCard(
                    label: 'Amount (Optional)',
                    controller: _amountController,
                    prefix: 'RWF',
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
                    color: const Color(0xFF0E1630),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
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
                              color: const Color(0xFF586C92),
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

  String _valueForRoute(
    PaymentRecipientType routeType,
    BiopayProfile? profile,
    UserProfile? user,
  ) {
    if (routeType == PaymentRecipientType.code) {
      if (profile?.routeType == PaymentRecipientType.code &&
          (profile?.recipientValue.trim().isNotEmpty ?? false)) {
        return profile!.recipientValue;
      }
      return '23456';
    }

    if (profile?.routeType == PaymentRecipientType.phoneNumber &&
        (profile?.recipientValue.trim().isNotEmpty ?? false)) {
      return profile!.recipientValue;
    }

    final momo = user?.momoNumber?.trim();
    return (momo != null && momo.isNotEmpty) ? momo : '0788123456';
  }
}
