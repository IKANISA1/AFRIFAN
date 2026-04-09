import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_enrollment_draft.dart';
import 'biopay_scan_screen.dart';

enum _RegisterStep { form, scan, success }

/// BioPay Registration — unified state-driven flow (Form -> Scan -> Success).
class BiopayRegisterScreen extends ConsumerStatefulWidget {
  const BiopayRegisterScreen({super.key});

  @override
  ConsumerState<BiopayRegisterScreen> createState() =>
      _BiopayRegisterScreenState();
}

class _BiopayRegisterScreenState extends ConsumerState<BiopayRegisterScreen> {
  final _recipientController = TextEditingController();
  PaymentRecipientType _routeType = PaymentRecipientType.phoneNumber;
  bool _consent = false;
  String? _error;

  _RegisterStep _step = _RegisterStep.form;
  BiopayEnrollmentDraft? _draft;

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  AfriCountry get _country => AfriCountryCatalog.defaultCountry;

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

  bool get _isValid => _validateRecipient() == null && _consent;

  void _proceed(String alias) {
    final validationError = _validateRecipient();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Consent required.');
      return;
    }
    HapticFeedback.mediumImpact();
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
    return AnimatedSwitcher(
      duration: AfriMotion.standard,
      child: switch (_step) {
        _RegisterStep.form => _buildForm(context),
        _RegisterStep.scan => BiopayScanScreen(
          key: const ValueKey('scan'),
          mode: BiopayScanMode.enroll,
          enrollmentDraft: _draft,
          onEnrollmentSuccess: () {
            setState(() => _step = _RegisterStep.success);
          },
          onCancel: () {
            setState(() => _step = _RegisterStep.form);
          },
        ),
        _RegisterStep.success => _buildSuccess(context),
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final authProfile = ref.watch(currentUserProvider);
    final alias = AliasGenerator.format(
      authProfile?.publicUserId ?? AliasGenerator.generate(),
    );

    return Scaffold(
      key: const ValueKey('form'),
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/biopay');
            }
          },
        ),
        title: Text('Face ID Setup', style: TypographyTokens.titleLarge()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: SpacingTokens.spacing6),

              // Bold headline
              Text(
                'Link your face\nto your MoMo.',
                style: TypographyTokens.displaySmall().copyWith(height: 1.15),
              ),

              const SizedBox(height: SpacingTokens.spacing8),

              // Segmented control
              _SegmentedControl(
                selected: _routeType,
                onChanged: (v) => setState(() {
                  _routeType = v;
                  _error = null;
                }),
                primaryColor: primaryColor,
              ),

              const SizedBox(height: SpacingTokens.spacing5),

              // Input field
              Text(
                _routeType == PaymentRecipientType.phoneNumber
                    ? 'MoMo Number'
                    : 'Merchant Code',
                style: TypographyTokens.labelSmall().copyWith(
                  color: primaryColor,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              ClayCard(
                backgroundColor: ColorTokens.background,
                borderRadius: BorderRadius.circular(32),
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing5,
                  vertical: SpacingTokens.spacing4,
                ),
                child: TextField(
                  controller: _recipientController,
                  keyboardType: _routeType == PaymentRecipientType.phoneNumber
                      ? TextInputType.phone
                      : TextInputType.text,
                  onChanged: (_) => setState(() => _error = null),
                  style: TypographyTokens.displaySmall().copyWith(fontSize: 28),
                  decoration: InputDecoration.collapsed(
                    hintText: _routeType == PaymentRecipientType.phoneNumber
                        ? _country.phoneExampleHint()
                        : 'Merchant code',
                    hintStyle: TypographyTokens.displaySmall().copyWith(
                      fontSize: 28,
                      color: ColorTokens.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
              ),

              // Consent
              const SizedBox(height: SpacingTokens.spacing5),
              AfriPressFeedback(
                onTap: () => setState(() => _consent = !_consent),
                scaleEnd: 0.97,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AfriMotion.quick,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _consent ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _consent
                              ? primaryColor
                              : ColorTokens.ghostBorder,
                          width: 1.5,
                        ),
                      ),
                      child: _consent
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Text(
                        'I consent to face processing for payment ID.',
                        style: TypographyTokens.bodySmall(),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  _error!,
                  style: TypographyTokens.bodySmall().copyWith(
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.error,
                  ),
                ),
              ],

              const Spacer(),

              // CTA
              ClaymorphicButton(
                label: 'Start Enrollment',
                onPressed: _isValid ? () => _proceed(alias) : null,
                width: double.infinity,
                preserveCase: true,
                letterSpacing: 0.6,
              ),

              const SizedBox(height: SpacingTokens.spacing8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Scaffold(
      key: const ValueKey('success'),
      backgroundColor: ColorTokens.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorTokens.success.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: ColorTokens.success,
                size: 48,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            Text('Face ID Active', style: TypographyTokens.displaySmall()),
            const SizedBox(height: SpacingTokens.spacing8),
            SizedBox(
              width: 200,
              child: ClaymorphicButton(
                label: 'Done',
                onPressed: () => context.go('/biopay/profile'),
                preserveCase: true,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segmented Control ──

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.selected,
    required this.onChanged,
    required this.primaryColor,
  });

  final PaymentRecipientType selected;
  final ValueChanged<PaymentRecipientType> onChanged;
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
          _SegmentTab(
            label: 'Number',
            isSelected: selected == PaymentRecipientType.phoneNumber,
            primaryColor: primaryColor,
            onTap: () => onChanged(PaymentRecipientType.phoneNumber),
          ),
          _SegmentTab(
            label: 'Code',
            isSelected: selected == PaymentRecipientType.code,
            primaryColor: primaryColor,
            onTap: () => onChanged(PaymentRecipientType.code),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
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
      child: AfriPressFeedback(
        onTap: onTap,
        scaleEnd: 0.96,
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
