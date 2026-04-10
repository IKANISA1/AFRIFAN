import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_enrollment_draft.dart';
import '../widgets/biopay_reference_ui.dart';
import 'biopay_scan_screen.dart';

enum _RegisterStep { form, scan, success }

class BiopayRegisterScreen extends ConsumerStatefulWidget {
  const BiopayRegisterScreen({super.key});

  @override
  ConsumerState<BiopayRegisterScreen> createState() =>
      _BiopayRegisterScreenState();
}

class _BiopayRegisterScreenState extends ConsumerState<BiopayRegisterScreen> {
  final _recipientController = TextEditingController();
  PaymentRecipientType _routeType = PaymentRecipientType.phoneNumber;
  String? _error;
  _RegisterStep _step = _RegisterStep.form;
  BiopayEnrollmentDraft? _draft;

  AfriCountry get _country => AfriCountryCatalog.defaultCountry;

  @override
  void initState() {
    super.initState();
    _recipientController.text = '0788123456';
  }

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  String? _validateRecipient() {
    final value = _recipientController.text.trim();
    if (value.isEmpty) {
      return _routeType == PaymentRecipientType.phoneNumber
          ? 'Enter your mobile money number.'
          : 'Enter your merchant code.';
    }

    try {
      if (_routeType == PaymentRecipientType.phoneNumber) {
        _country.normalizeNationalPhone(value);
      } else {
        _country.normalizeMerchantCode(value);
      }
      return null;
    } catch (error) {
      return error
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Unsupported operation: ', '');
    }
  }

  String _normalizedRecipient() {
    final value = _recipientController.text.trim();
    if (_routeType == PaymentRecipientType.phoneNumber) {
      return _country.normalizeNationalPhone(value);
    }
    return _country.normalizeMerchantCode(value);
  }

  void _switchRouteType(PaymentRecipientType routeType) {
    setState(() {
      _routeType = routeType;
      _error = null;
      _recipientController.text = routeType == PaymentRecipientType.phoneNumber
          ? '0788123456'
          : '23456';
    });
  }

  void _startEnrollment() {
    final validationError = _validateRecipient();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final user = ref.read(currentUserProvider);
    final alias = user?.publicUserId?.trim().isNotEmpty == true
        ? user!.publicUserId!
        : '882931';

    setState(() {
      _draft = BiopayEnrollmentDraft(
        displayName: alias,
        routeType: _routeType,
        recipientValue: _normalizedRecipient(),
        countryCode: _country.isoCode,
        consentVersion: 'biopay-v1',
      );
      _step = _RegisterStep.scan;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _RegisterStep.form => _buildForm(context),
      _RegisterStep.scan => BiopayScanScreen(
        mode: BiopayScanMode.enroll,
        enrollmentDraft: _draft,
        onEnrollmentSuccess: () =>
            setState(() => _step = _RegisterStep.success),
        onCancel: () => setState(() => _step = _RegisterStep.form),
      ),
      _RegisterStep.success => _buildSuccess(context),
    };
  }

  Widget _buildForm(BuildContext context) {
    return BiopayReferencePage(
      title: 'Face ID Setup',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/biopay/profile');
        }
      },
      child: ListView(
        children: [
          const SizedBox(height: 6),
          Text(
            'Link your face\nto your MoMo.',
            style: biopayReferenceText(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 34),
          BiopayReferenceSegmentedControl(
            selected: _routeType,
            onChanged: _switchRouteType,
          ),
          const SizedBox(height: 22),
          BiopayReferenceValueCard(
            label: _routeType == PaymentRecipientType.code
                ? 'Merchant Code'
                : 'MoMo Number',
            controller: _recipientController,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
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
          const SizedBox(height: 48),
          BiopayReferencePrimaryButton(
            label: 'Start Enrollment',
            onTap: _startEnrollment,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final bioPayId = user?.publicUserId?.trim().isNotEmpty == true
        ? user!.publicUserId!
        : '882931';

    return Scaffold(
      backgroundColor: biopayReferenceBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BiopayReferenceLightBackButton(
                    onTap: () => context.go('/biopay'),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 132,
                      height: 132,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD7F8DE),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: biopayReferenceGreen,
                        size: 70,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'ENROLLMENT SUCCESS',
                      style: biopayReferenceText(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: biopayReferenceMuted,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Face ID Ready',
                      style: biopayReferenceText(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BioPay ID: $bioPayId',
                      style: biopayReferenceText(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF667A9E),
                      ),
                    ),
                    const SizedBox(height: 42),
                    BiopayReferencePrimaryButton(
                      label: 'Done',
                      onTap: () => context.go('/biopay'),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => context.go('/biopay/profile'),
                      child: Text(
                        'Go to Profile',
                        style: biopayReferenceText(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: biopayReferenceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
