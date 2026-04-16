import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupporterPhoneAuthScreen extends ConsumerStatefulWidget {
  const SupporterPhoneAuthScreen({super.key});

  @override
  ConsumerState<SupporterPhoneAuthScreen> createState() =>
      _SupporterPhoneAuthScreenState();
}

class _SupporterPhoneAuthScreenState
    extends ConsumerState<SupporterPhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  static const OtpChannel _deliveryChannel = OtpChannel.whatsapp;
  String? _pendingPhone;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String get _phoneValue => _phoneController.text.trim();
  String get _otpValue => _otpController.text.trim();
  bool get _canSubmitPhone =>
      _phoneValue.isNotEmpty && _resendCooldown == 0;
  bool get _canSubmitOtp =>
      (_pendingPhone?.isNotEmpty ?? false) && _otpValue.length >= 6;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onChanged);
    _otpController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController
      ..removeListener(_onChanged)
      ..dispose();
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
    setState(() {
      _isLoading = false;
      if (error == null) {
        _pendingPhone = normalizedPhone;
        _otpController.clear();
        _startCooldown();
      }
    });

    final message =
        error ?? 'Verification code sent to WhatsApp for $normalizedPhone.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _verifyCode() async {
    if (_isLoading || !_canSubmitOtp) return;

    final pendingPhone = _pendingPhone;
    if (pendingPhone == null) return;

    setState(() => _isLoading = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .verifyPhoneSignInOtp(phone: pendingPhone, token: _otpValue);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      context.go(_postAuthDestination());
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    } on StateError {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Country metadata is unavailable for this build.'),
        ),
      );
      return null;
    }
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
        path == '/auth/phone') {
      return '/home';
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AfriIcons.back),
          onPressed: () {
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
              Text('SIGN IN WITH OTP', style: TypographyTokens.headlineLarge()),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                'We’ll send a 6-digit code to your WhatsApp.',
                style: TypographyTokens.bodyLarge().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERY CHANNEL',
                      style: TypographyTokens.labelMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(SpacingTokens.spacing4),
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: BorderTokens.all(color: ColorTokens.ghostBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(AfriIcons.chat),
                          const SizedBox(width: SpacingTokens.spacing3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code via WhatsApp',
                                  style: TypographyTokens.labelLarge(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing5),
                    AfriInputField(
                      controller: _phoneController,
                      label: 'Phone number',
                      hint: '+2507...',
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      prefixIcon: AfriIcons.help,
                      maxLength: 20,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      key: const ValueKey<String>('supporter-send-otp-button'),
                      label: _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : (_pendingPhone == null
                              ? 'Send code'
                              : 'Resend code'),
                      onTap: _sendCode,
                      isLoading: _isLoading && _pendingPhone == null,
                      enabled: !_isLoading && _canSubmitPhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENTER OTP', style: TypographyTokens.labelMedium()),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      _pendingPhone == null
                          ? 'Request a code first.'
                          : 'Code sent to $_pendingPhone.',
                      style: TypographyTokens.bodyMedium().copyWith(
                        color: ColorTokens.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriInputField(
                      controller: _otpController,
                      label: '6-digit OTP',
                      hint: '123456',
                      keyboardType: TextInputType.number,
                      enabled: (_pendingPhone?.isNotEmpty ?? false) && !_isLoading,
                      prefixIcon: AfriIcons.privacy,
                      maxLength: 6,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      key: const ValueKey<String>('supporter-verify-otp-button'),
                      label: 'Verify & continue',
                      onTap: _verifyCode,
                      isLoading: _isLoading,
                      enabled: !_isLoading && _canSubmitOtp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await ref
                            .read(authStateProvider.notifier)
                            .signInAnonymously();
                        if (!mounted) return;
                        setState(() => _isLoading = false);

                        final nextState = ref.read(authStateProvider);
                        if (nextState is AuthAuthenticated) {
                          context.go(_postAuthDestination());
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not start anonymous session.',
                            ),
                          ),
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
