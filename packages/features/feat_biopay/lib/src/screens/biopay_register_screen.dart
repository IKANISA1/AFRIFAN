import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../biopay_display_resolver.dart';
import '../biopay_tokens.dart';
import '../models/biopay_enrollment_draft.dart';
import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';
import 'biopay_scan_screen.dart';

enum _RegisterStep { form, scan, success }

class BioPayRegisterScreen extends ConsumerStatefulWidget {
  const BioPayRegisterScreen({super.key});

  @override
  ConsumerState<BioPayRegisterScreen> createState() =>
      _BioPayRegisterScreenState();
}

class _BioPayRegisterScreenState extends ConsumerState<BioPayRegisterScreen> {
  final _recipientController = TextEditingController();
  PaymentRecipientType _routeType = PaymentRecipientType.phoneNumber;
  String? _error;
  _RegisterStep _step = _RegisterStep.form;
  BioPayEnrollmentDraft? _draft;

  AfriCountry get _country => AfriCountryCatalog.defaultCountry;

  @override
  void initState() {
    super.initState();
    _recipientController.text = initialBioPayRecipientValue(
      _routeType,
      ref.read(BioPayProfileProvider).valueOrNull,
      ref.read(currentUserProvider),
      _country,
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  void _switchRouteType(PaymentRecipientType routeType) {
    setState(() {
      _routeType = routeType;
      _error = null;
      _recipientController.text = initialBioPayRecipientValue(
        routeType,
        ref.read(BioPayProfileProvider).valueOrNull,
        ref.read(currentUserProvider),
        _country,
      );
    });
  }

  void _startEnrollment() {
    final validationError = validateBioPayRecipient(
      routeType: _routeType,
      value: _recipientController.text,
      country: _country,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final user = ref.read(currentUserProvider);
    final alias = BioPayEnrollmentAlias(user);

    setState(() {
      _draft = BioPayEnrollmentDraft(
        displayName: alias,
        routeType: _routeType,
        recipientValue: normalizeBioPayRecipient(
          routeType: _routeType,
          value: _recipientController.text,
          country: _country,
        ),
        countryCode: _country.isoCode,
        consentVersion: 'BioPay-v1',
      );
      _step = _RegisterStep.scan;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _RegisterStep.form => _buildForm(context),
      _RegisterStep.scan => BioPayScanScreen(
        mode: BioPayScanMode.enroll,
        enrollmentDraft: _draft,
        onEnrollmentSuccess: () =>
            setState(() => _step = _RegisterStep.success),
        onCancel: () => setState(() => _step = _RegisterStep.form),
      ),
      _RegisterStep.success => _buildSuccess(context),
    };
  }

  Widget _buildForm(BuildContext context) {
    return BioPayReferencePage(
      title: 'Face ID Setup',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/BioPay/profile');
        }
      },
      child: ListView(
        children: [
          Text(
            'Link Face ID\nto this route',
            style: BioPayReferenceText(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This number or code is saved only for Face ID payments.',
            style: BioPayReferenceText(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: BioPayReferenceMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 34),
          BioPayReferenceSegmentedControl(
            selected: _routeType,
            onChanged: _switchRouteType,
          ),
          const SizedBox(height: 22),
          BioPayReferenceValueCard(
            label: _routeType == PaymentRecipientType.code
                ? 'Merchant Code'
                : 'MoMo Number',
            controller: _recipientController,
            hintText: BioPayRecipientHint(_routeType, _country),
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
              style: BioPayReferenceText(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BioPayTokens.errorAccent,
              ),
            ),
          ],
          const SizedBox(height: 48),
          BioPayReferencePrimaryButton(
            label: 'Start Enrollment',
            onTap: _startEnrollment,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final profile = ref.watch(BioPayProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final BioPayId = resolveBioPayId(profile, user) ?? kBioPayPendingSyncLabel;

    return Scaffold(
      backgroundColor: BioPayReferenceBackground,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BioPayReferenceLightBackButton(
                      onTap: () => context.go('/BioPay'),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: BioPayTokens.successPanel,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: BioPayReferenceGreen,
                          size: 70,
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        'Enrollment successful',
                        style: BioPayReferenceText(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BioPayReferenceMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Face ID Ready',
                        style: BioPayReferenceText(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'BioPay ID: $BioPayId',
                        style: BioPayReferenceText(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: BioPayTokens.mutedDark,
                        ),
                      ),
                      const SizedBox(height: 42),
                      BioPayReferencePrimaryButton(
                        label: 'Done',
                        onTap: () => context.go('/BioPay'),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () => context.go('/BioPay/profile'),
                        child: Text(
                          'Go to Profile',
                          style: BioPayReferenceText(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: BioPayReferenceMuted,
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
      ),
    );
  }
}
