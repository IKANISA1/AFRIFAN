import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supporterPhoneAuthTestNumber = '+250788767816';
const supporterPhoneAuthTestOtp = '12345';

class SupporterPhoneAuthScreen extends ConsumerStatefulWidget {
  const SupporterPhoneAuthScreen({super.key});

  @override
  ConsumerState<SupporterPhoneAuthScreen> createState() =>
      _SupporterPhoneAuthScreenState();
}

class _SupporterPhoneAuthScreenState
    extends ConsumerState<SupporterPhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  static const OtpChannel _deliveryChannel = OtpChannel.whatsapp;

  String get _phoneValue => _phoneController.text.trim();
  bool get _canSubmitPhone => _phoneValue.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendCode() async {
    if (_isLoading || !_canSubmitPhone) return;

    final normalizedPhone = _normalizePhone(_phoneValue);
    if (normalizedPhone == null) return;

    setState(() => _isLoading = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .requestPhoneSignInOtp(
          phone: normalizedPhone,
          channel: _deliveryChannel,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      AfriToast.error(context, error);
      return;
    }

    context.go(
      Uri(
        path: '/auth/otp',
        queryParameters: <String, String>{
          'phone': normalizedPhone,
          if (_deferredDestination() case final String from) 'from': from,
        },
      ).toString(),
    );
  }

  String? _normalizePhone(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^\+\d{10,15}$').hasMatch(compact)) {
      return compact;
    }

    final config = ClubConfigScope.maybeOf(context);

    try {
      final country = AfriCountryCatalog.resolve(
        country: config?.countryCode ?? config?.country,
      );
      return country.buildE164Phone(value);
    } on FormatException catch (error) {
      AfriToast.error(context, error.message);
      return null;
    } on StateError {
      AfriToast.error(
        context,
        'Country metadata is unavailable for this build.',
      );
      return null;
    }
  }

  String? _deferredDestination() {
    final raw = GoRouterState.of(context).uri.queryParameters['from']?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path == '/splash' ||
        path == '/onboarding' ||
        path == '/auth/phone' ||
        path == '/auth/otp') {
      return null;
    }

    return uri.toString();
  }

  String _postAuthDestination() {
    return _deferredDestination() ?? '/home';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.transparent,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: 'Back',
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/onboarding');
            }
          },
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.screenPadding,
              SpacingTokens.spacing2,
              SpacingTokens.screenPadding,
              SpacingTokens.spacing8,
            ),
            children: [
              const _AuthStepHeader(
                eyebrow: 'WhatsApp sign in',
                title: 'Enter your mobile number',
                body: 'We will send a secure code to your WhatsApp.',
                icon: AfriIcons.phone,
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              AfriSurfaceCard(
                backgroundColor: ColorTokens.surfaceContainerLow.withValues(
                  alpha: 0.88,
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AfriInputField(
                      key: const ValueKey<String>('supporter-phone-input'),
                      controller: _phoneController,
                      label: 'WhatsApp number',
                      hint: supporterPhoneAuthTestNumber,
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      prefixIcon: AfriIcons.phone,
                      maxLength: 20,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendCode(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      key: const ValueKey<String>('supporter-send-otp-button'),
                      label: 'Send WhatsApp code',
                      icon: AfriIcons.forward,
                      onTap: _sendCode,
                      isLoading: _isLoading,
                      enabled: !_isLoading && _canSubmitPhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriTextButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await ref
                            .read(authStateProvider.notifier)
                            .signInAnonymously();
                        if (!mounted || !context.mounted) return;
                        setState(() => _isLoading = false);

                        final nextState = ref.read(authStateProvider);
                        if (nextState is AuthAuthenticated) {
                          context.go(_postAuthDestination());
                          return;
                        }

                        AfriToast.error(
                          context,
                          'Could not start anonymous session.',
                        );
                      },
                child: const Text('Continue without sign-in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupporterOtpVerificationScreen extends ConsumerStatefulWidget {
  const SupporterOtpVerificationScreen({super.key});

  @override
  ConsumerState<SupporterOtpVerificationScreen> createState() =>
      _SupporterOtpVerificationScreenState();
}

class _SupporterOtpVerificationScreenState
    extends ConsumerState<SupporterOtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String get _otpValue => _otpController.text.trim();
  bool get _canSubmitOtp => _phone.isNotEmpty && _otpValue.length >= 5;

  String get _phone =>
      GoRouterState.of(context).uri.queryParameters['phone']?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onChanged);
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_isResending || _isVerifying || _resendCooldown > 0 || _phone.isEmpty) {
      return;
    }

    setState(() => _isResending = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .requestPhoneSignInOtp(phone: _phone, channel: OtpChannel.whatsapp);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (error == null) {
      _startCooldown();
      AfriToast.success(context, 'New WhatsApp code sent to $_phone.');
      return;
    }

    AfriToast.error(context, error);
  }

  Future<void> _verifyCode() async {
    if (_isVerifying || !_canSubmitOtp) return;

    setState(() => _isVerifying = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .verifyPhoneSignInOtp(phone: _phone, token: _otpValue);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (error == null) {
      context.go(_postAuthDestination());
      return;
    }

    AfriToast.error(context, error);
  }

  String _postAuthDestination() {
    final raw = GoRouterState.of(context).uri.queryParameters['from']?.trim();
    if (raw == null || raw.isEmpty) {
      return '/home';
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path == '/splash' ||
        path == '/onboarding' ||
        path == '/auth/phone' ||
        path == '/auth/otp') {
      return '/home';
    }

    return uri.toString();
  }

  String _phoneEntryRoute() {
    return Uri(
      path: '/auth/phone',
      queryParameters: <String, String>{
        if (GoRouterState.of(context).uri.queryParameters['from']
            case final String from)
          'from': from,
      },
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_phone.isEmpty) {
      return Scaffold(
        backgroundColor: ColorTokens.transparent,
        body: GradientBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: AfriStateView.error(
                  title: 'Phone number missing',
                  message: 'Start again to request a WhatsApp code.',
                  actionLabel: 'Enter number',
                  onAction: () => context.go(_phoneEntryRoute()),
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ColorTokens.transparent,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: 'Change number',
          onTap: () => context.go(_phoneEntryRoute()),
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SpacingTokens.screenPadding,
              SpacingTokens.spacing2,
              SpacingTokens.screenPadding,
              SpacingTokens.spacing8,
            ),
            children: [
              _AuthStepHeader(
                eyebrow: 'Check WhatsApp',
                title: 'Enter your code',
                body: 'Code sent to $_phone.',
                icon: AfriIcons.privacy,
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              AfriSurfaceCard(
                backgroundColor: ColorTokens.surfaceContainerLow.withValues(
                  alpha: 0.88,
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AfriInputField(
                      key: const ValueKey<String>('supporter-phone-otp-input'),
                      controller: _otpController,
                      label: 'WhatsApp code',
                      hint: supporterPhoneAuthTestOtp,
                      keyboardType: TextInputType.number,
                      enabled: !_isVerifying && !_isResending,
                      prefixIcon: AfriIcons.privacy,
                      maxLength: 6,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verifyCode(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      key: const ValueKey<String>(
                        'supporter-verify-otp-button',
                      ),
                      label: 'Verify and continue',
                      icon: AfriIcons.verified,
                      onTap: _verifyCode,
                      isLoading: _isVerifying,
                      enabled: !_isVerifying && !_isResending && _canSubmitOtp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Row(
                children: [
                  Expanded(
                    child: AfriTextIconButton(
                      onPressed:
                          (_resendCooldown > 0 || _isResending || _isVerifying)
                          ? null
                          : _resendCode,
                      icon: Icon(
                        _resendCooldown > 0 ? AfriIcons.timer : AfriIcons.chat,
                      ),
                      label: Text(
                        _resendCooldown > 0
                            ? 'Resend in ${_resendCooldown}s'
                            : 'Resend code',
                      ),
                    ),
                  ),
                  AfriTextButton(
                    onPressed: (_isResending || _isVerifying)
                        ? null
                        : () => context.go(_phoneEntryRoute()),
                    child: const Text('Change number'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthStepHeader extends StatelessWidget {
  const _AuthStepHeader({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: ColorTokens.primaryContainer,
            borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
            boxShadow: AfriShadows.primaryGlow(ColorTokens.primaryContainer),
          ),
          child: Icon(icon, color: ColorTokens.onSurface),
        ),
        const SizedBox(height: SpacingTokens.spacing5),
        Text(
          eyebrow.toUpperCase(),
          style: TypographyTokens.labelMedium().copyWith(
            color: ColorTokens.primaryContainer,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(title, style: TypographyTokens.headlineLarge()),
        const SizedBox(height: SpacingTokens.spacing3),
        Text(
          body,
          style: TypographyTokens.bodyLarge().copyWith(
            color: ColorTokens.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
