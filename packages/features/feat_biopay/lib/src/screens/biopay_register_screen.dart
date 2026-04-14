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
    _recipientController.text = initialBiopayRecipientValue(
      _routeType,
      ref.read(biopayProfileProvider).valueOrNull,
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
      _recipientController.text = initialBiopayRecipientValue(
        routeType,
        ref.read(biopayProfileProvider).valueOrNull,
        ref.read(currentUserProvider),
        _country,
      );
    });
  }

  void _startEnrollment() {
    final validationError = validateBiopayRecipient(
      routeType: _routeType,
      value: _recipientController.text,
      country: _country,
    );
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    final user = ref.read(currentUserProvider);
    final alias = biopayEnrollmentAlias(user);

    setState(() {
      _draft = BiopayEnrollmentDraft(
        displayName: alias,
        routeType: _routeType,
        recipientValue: normalizeBiopayRecipient(
          routeType: _routeType,
          value: _recipientController.text,
          country: _country,
        ),
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
            'Link Face ID\nto this route.',
            style: biopayReferenceText(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This number or code is saved only for Face ID payments.',
            style: biopayReferenceText(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: biopayReferenceMuted,
              height: 1.4,
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
            hintText: biopayRecipientHint(_routeType, _country),
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
                color: BiopayTokens.errorAccent,
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
    final profile = ref.watch(biopayProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final bioPayId = resolveBiopayId(profile, user) ?? kBiopayPendingSyncLabel;

    return Scaffold(
      backgroundColor: biopayReferenceBackground,
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: BiopayTokens.successPanel,
                        ),
                        child: Icon(
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
                          color: BiopayTokens.mutedDark,
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
      ),
    );
  }
}
