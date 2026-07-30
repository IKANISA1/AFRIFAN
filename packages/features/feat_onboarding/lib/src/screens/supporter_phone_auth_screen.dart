import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupporterPhoneAuthScreen extends ConsumerStatefulWidget {
  const SupporterPhoneAuthScreen({super.key, this.connectivity});

  final ValueListenable<bool>? connectivity;

  @override
  ConsumerState<SupporterPhoneAuthScreen> createState() =>
      _SupporterPhoneAuthScreenState();
}

class _SupporterPhoneAuthScreenState
    extends ConsumerState<SupporterPhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode(debugLabel: 'WhatsApp number');
  final ScrollController _phoneScrollController = ScrollController();

  bool _isLoading = false;
  AuthActionFailure? _phoneFailure;
  late final ValueListenable<bool> _connectivity;
  static const OtpChannel _deliveryChannel = OtpChannel.whatsapp;

  String get _phoneValue => _phoneController.text.trim();
  bool get _canSubmitPhone {
    final compact = _phoneValue.replaceAll(RegExp(r'[\s()-]'), '');
    if (compact.startsWith('+')) {
      return RegExp(r'^\+\d{10,15}$').hasMatch(compact);
    }
    return RegExp(r'^\d{9,15}$').hasMatch(compact);
  }

  bool get _isOnline => _connectivity.value;
  String? _phoneError(AfriLocalizations l10n) =>
      _phoneFailure?.kind == AuthActionFailureKind.invalidInput
      ? l10n.authPhoneInvalidMessage
      : null;

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivity ?? ConnectivityService.onlineNotifier;
    _connectivity.addListener(_handleConnectivityChange);
    if (!_isOnline) {
      _phoneFailure = _offlinePhoneFailure;
    }
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _connectivity.removeListener(_handleConnectivityChange);
    _phoneFocusNode.dispose();
    _phoneScrollController.dispose();
    _phoneController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {
        _phoneFailure = _isOnline ? null : _offlinePhoneFailure;
      });
    }
  }

  void _handleConnectivityChange() {
    if (!mounted) return;
    setState(() {
      if (!_isOnline) {
        _phoneFailure = _offlinePhoneFailure;
      } else if (_phoneFailure?.kind == AuthActionFailureKind.offline) {
        _phoneFailure = null;
      }
    });
  }

  Future<void> _sendCode() async {
    if (_isLoading || !_canSubmitPhone) return;
    if (!_isOnline) {
      setState(() => _phoneFailure = _offlinePhoneFailure);
      return;
    }

    final normalizedPhone = _normalizePhone(_phoneValue);
    if (normalizedPhone == null) return;

    setState(() {
      _isLoading = true;
      _phoneFailure = null;
    });
    final failure = await ref
        .read(authStateProvider.notifier)
        .requestPhoneSignInOtpResult(
          phone: normalizedPhone,
          channel: _deliveryChannel,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _phoneFailure = failure;
    });

    if (failure != null) {
      _revealPhoneField();
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
      setState(
        () => _phoneFailure = AuthActionFailure(
          kind: AuthActionFailureKind.invalidInput,
          message: error.message,
        ),
      );
      return null;
    } on StateError {
      setState(
        () => _phoneFailure = AuthActionFailure(
          kind: AuthActionFailureKind.unknown,
          message: context.afriL10n.authCountryUnavailable,
        ),
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

  void _editNumber() {
    setState(() {
      _phoneFailure = _isOnline ? null : _offlinePhoneFailure;
    });
    _phoneFocusNode.requestFocus();
    _revealPhoneField();
  }

  void _revealPhoneField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_phoneScrollController.hasClients) return;
      unawaited(
        _phoneScrollController.animateTo(
          _phoneScrollController.position.maxScrollExtent,
          duration: AfriMotion.resolve(context, AfriMotion.standard),
          curve: AfriMotion.enterCurve,
        ),
      );
    });
  }

  Widget? _buildPhoneStatus() {
    final l10n = context.afriL10n;
    if (_isLoading) {
      return AfriStateView.loading(
        key: const ValueKey<String>('supporter-phone-state'),
        title: l10n.authSendingCodeTitle,
        message: l10n.authSendingCodeMessage,
        compact: true,
      );
    }

    final failure = _phoneFailure;
    if (failure == null) return null;
    if (failure.kind == AuthActionFailureKind.offline) {
      return AfriStateView.offline(
        key: const ValueKey<String>('supporter-phone-state'),
        title: l10n.connectionRequired,
        message: l10n.authPhoneOfflineMessage,
        compact: true,
      );
    }

    final title = switch (failure.kind) {
      AuthActionFailureKind.permissionDenied => l10n.authSignInUnavailableTitle,
      AuthActionFailureKind.securityTimeout => l10n.authRequestTimeoutTitle,
      AuthActionFailureKind.conflict => l10n.authNumberLinkedTitle,
      AuthActionFailureKind.invalidInput => l10n.authCheckNumberTitle,
      AuthActionFailureKind.unknown => l10n.authCodeNotSentTitle,
      AuthActionFailureKind.offline => l10n.connectionRequired,
    };
    return AfriStateView.error(
      key: const ValueKey<String>('supporter-phone-state'),
      title: title,
      message: _localizedPhoneFailureMessage(l10n, failure.kind),
      actionLabel: l10n.authEditNumber,
      onAction: _editNumber,
      compact: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final phoneStatus = _buildPhoneStatus();
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final protectPhoneValue =
        _phoneValue.isNotEmpty && (_isLoading || _phoneFailure != null);
    final phoneColors = context.afriSemanticColors;
    final guestActionColor = _isLoading
        ? ColorTokens.accessibleDisabledColor(phoneColors.secondaryText)
        : phoneColors.primaryText;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.transparent,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: l10n.authBack,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/onboarding');
            }
          },
        ),
      ),
      scrollable: false,
      bodyWrapper: (child) => GradientBackground(child: child),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: _phoneScrollController,
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.screenPadding,
            SpacingTokens.spacing2,
            SpacingTokens.screenPadding,
            SpacingTokens.spacing8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthStepHeader(
                eyebrow: l10n.authWhatsAppEyebrow,
                title: l10n.authEnterNumberTitle,
                body: l10n.authEnterNumberBody,
                icon: AfriIcons.chat,
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              if (phoneStatus != null) ...[
                phoneStatus,
                const SizedBox(height: SpacingTokens.spacing4),
              ],
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
                      focusNode: _phoneFocusNode,
                      label: usesLargeText
                          ? l10n.authPhoneLabel
                          : l10n.authWhatsAppNumberLabel,
                      hint: l10n.authPhoneHint,
                      helperText: l10n.authPhonePrivacy,
                      helperMaxLines: 2,
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      obscureText: protectPhoneValue,
                      prefixIcon: AfriIcons.phone,
                      maxLength: 20,
                      autofocus: !usesLargeText,
                      textInputAction: TextInputAction.done,
                      errorText: _phoneError(l10n),
                      autofillHints: const <String>[
                        AutofillHints.telephoneNumber,
                      ],
                      enableSuggestions: false,
                      autocorrect: false,
                      onSubmitted: (_) => _sendCode(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      key: const ValueKey<String>('supporter-send-otp-button'),
                      label: _isOnline
                          ? l10n.authSendCode
                          : l10n.connectionRequired,
                      icon: AfriIcons.forward,
                      onTap: _sendCode,
                      isLoading: _isLoading,
                      enabled: _isOnline && !_isLoading && _canSubmitPhone,
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
                          l10n.authGuestSessionUnavailable,
                        );
                      },
                child: Text(
                  l10n.onboardingContinueWithoutSignIn,
                  style: TypographyTokens.labelLarge(guestActionColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupporterOtpVerificationScreen extends ConsumerStatefulWidget {
  const SupporterOtpVerificationScreen({
    super.key,
    this.connectivity,
    this.resendCooldown = const Duration(seconds: 60),
  });

  final ValueListenable<bool>? connectivity;
  final Duration resendCooldown;

  @override
  ConsumerState<SupporterOtpVerificationScreen> createState() =>
      _SupporterOtpVerificationScreenState();
}

class _SupporterOtpVerificationScreenState
    extends ConsumerState<SupporterOtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode(debugLabel: 'WhatsApp code');
  final ScrollController _otpScrollController = ScrollController(
    keepScrollOffset: false,
  );

  bool _isVerifying = false;
  bool _isResending = false;
  AuthActionFailure? _otpFailure;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  late final ValueListenable<bool> _connectivity;

  String get _otpValue => _otpController.text.trim();
  bool get _canSubmitOtp => _phone.isNotEmpty && _otpValue.length >= 5;
  bool get _isOnline => _connectivity.value;
  String? _otpError(AfriLocalizations l10n) => switch (_otpFailure?.kind) {
    AuthActionFailureKind.invalidInput => l10n.authOtpInvalidMessage,
    AuthActionFailureKind.securityTimeout => l10n.authOtpExpiredMessage,
    _ => null,
  };

  String get _phone =>
      GoRouterState.of(context).uri.queryParameters['phone']?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivity ?? ConnectivityService.onlineNotifier;
    _connectivity.addListener(_handleConnectivityChange);
    if (!_isOnline) {
      _otpFailure = _offlineOtpFailure;
    }
    _otpController.addListener(_onChanged);
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _connectivity.removeListener(_handleConnectivityChange);
    _otpFocusNode.dispose();
    _otpScrollController.dispose();
    _otpController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {
        _otpFailure = _isOnline ? null : _offlineOtpFailure;
      });
    }
  }

  void _handleConnectivityChange() {
    if (!mounted) return;
    setState(() {
      if (!_isOnline) {
        _otpFailure = _offlineOtpFailure;
      } else if (_otpFailure?.kind == AuthActionFailureKind.offline) {
        _otpFailure = null;
      }
    });
  }

  void _startCooldown() {
    _resendCooldown = widget.resendCooldown.inSeconds;
    _cooldownTimer?.cancel();
    if (_resendCooldown <= 0) return;
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
    if (!_isOnline) {
      setState(() => _otpFailure = _offlineOtpFailure);
      return;
    }

    setState(() {
      _isResending = true;
      _otpFailure = null;
    });
    final failure = await ref
        .read(authStateProvider.notifier)
        .requestPhoneSignInOtpResult(
          phone: _phone,
          channel: OtpChannel.whatsapp,
        );

    if (!mounted) return;
    setState(() {
      _isResending = false;
      _otpFailure = failure;
    });

    if (failure == null) {
      _startCooldown();
      AfriToast.success(context, context.afriL10n.authNewCodeSent);
      return;
    }
  }

  Future<void> _verifyCode() async {
    if (_isVerifying || !_canSubmitOtp) return;
    if (!_isOnline) {
      setState(() => _otpFailure = _offlineOtpFailure);
      return;
    }

    setState(() {
      _isVerifying = true;
      _otpFailure = null;
    });
    final failure = await ref
        .read(authStateProvider.notifier)
        .verifyPhoneSignInOtpResult(phone: _phone, token: _otpValue);

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _otpFailure = failure;
    });

    if (failure == null) {
      context.go(_postAuthDestination());
      return;
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

  void _editCode() {
    setState(() {
      _otpFailure = _isOnline ? null : _offlineOtpFailure;
    });
    _otpFocusNode.requestFocus();
  }

  Widget? _buildOtpStatus() {
    final l10n = context.afriL10n;
    if (_isVerifying || _isResending) {
      return AfriStateView.loading(
        key: const ValueKey<String>('supporter-otp-state'),
        title: _isResending
            ? l10n.authSendingNewCodeTitle
            : l10n.authCheckingCodeTitle,
        message: _isResending
            ? l10n.authSendingNewCodeMessage
            : l10n.authCheckingCodeMessage,
        compact: true,
      );
    }

    final failure = _otpFailure;
    if (failure == null) return null;
    if (failure.kind == AuthActionFailureKind.offline) {
      return AfriStateView.offline(
        key: const ValueKey<String>('supporter-otp-state'),
        title: l10n.connectionRequired,
        message: l10n.authOtpOfflineMessage,
        compact: true,
      );
    }

    final title = switch (failure.kind) {
      AuthActionFailureKind.permissionDenied =>
        l10n.authVerificationUnavailableTitle,
      AuthActionFailureKind.securityTimeout => l10n.authCodeExpiredTitle,
      AuthActionFailureKind.conflict => l10n.authNumberLinkedTitle,
      AuthActionFailureKind.invalidInput => l10n.authCodeNotAcceptedTitle,
      AuthActionFailureKind.unknown => l10n.authVerificationFailedTitle,
      AuthActionFailureKind.offline => l10n.connectionRequired,
    };
    return AfriStateView.error(
      key: const ValueKey<String>('supporter-otp-state'),
      title: title,
      message: _localizedOtpFailureMessage(l10n, failure.kind),
      actionLabel: l10n.authCheckCode,
      onAction: _editCode,
      compact: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    if (_phone.isEmpty) {
      return AfriScreenScaffold(
        backgroundColor: ColorTokens.transparent,
        showAppBar: false,
        showBackButton: false,
        scrollable: false,
        bodyWrapper: (child) => GradientBackground(child: child),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              child: AfriStateView.error(
                title: l10n.authPhoneMissingTitle,
                message: l10n.authPhoneMissingMessage,
                actionLabel: l10n.authEnterNumberTitle,
                onAction: () => context.go(_phoneEntryRoute()),
                compact: true,
              ),
            ),
          ),
        ),
      );
    }

    final otpStatus = _buildOtpStatus();
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final otpColors = context.afriSemanticColors;
    final resendDisabled =
        _resendCooldown > 0 || _isResending || _isVerifying || !_isOnline;
    final changeNumberDisabled = _isResending || _isVerifying;
    final resendActionColor = resendDisabled
        ? ColorTokens.accessibleDisabledColor(otpColors.secondaryText)
        : otpColors.primaryText;
    final changeNumberActionColor = changeNumberDisabled
        ? ColorTokens.accessibleDisabledColor(otpColors.secondaryText)
        : otpColors.primaryText;
    final resendAction = AfriTextIconButton(
      onPressed: resendDisabled ? null : _resendCode,
      icon: Icon(
        _resendCooldown > 0 ? AfriIcons.timer : AfriIcons.chat,
        color: resendActionColor,
      ),
      label: Text(
        !_isOnline
            ? l10n.connectionRequired
            : _resendCooldown > 0
            ? l10n.authResendIn(_resendCooldown)
            : l10n.authResendCode,
        style: TypographyTokens.labelLarge(resendActionColor),
      ),
    );
    final changeNumberAction = AfriTextButton(
      onPressed: changeNumberDisabled
          ? null
          : () => context.go(_phoneEntryRoute()),
      child: Text(
        l10n.authChangeNumber,
        style: TypographyTokens.labelLarge(changeNumberActionColor),
      ),
    );

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.transparent,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: l10n.authChangeNumber,
          onTap: () => context.go(_phoneEntryRoute()),
        ),
      ),
      scrollable: false,
      bodyWrapper: (child) => GradientBackground(child: child),
      child: SafeArea(
        child: ListView(
          controller: _otpScrollController,
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.screenPadding,
            SpacingTokens.spacing2,
            SpacingTokens.screenPadding,
            SpacingTokens.spacing8,
          ),
          children: [
            _AuthStepHeader(
              eyebrow: l10n.authCheckWhatsAppEyebrow,
              title: l10n.authEnterCodeTitle,
              body: l10n.authEnterCodeBody,
              icon: AfriIcons.chat,
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            if (otpStatus != null) ...[
              otpStatus,
              const SizedBox(height: SpacingTokens.spacing4),
            ],
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
                    focusNode: _otpFocusNode,
                    label: usesLargeText
                        ? l10n.authCodeLabel
                        : l10n.authWhatsAppCodeLabel,
                    hint: l10n.authCodeHint,
                    helperText: l10n.authCodePrivacy,
                    helperMaxLines: 2,
                    keyboardType: TextInputType.number,
                    enabled: !_isVerifying && !_isResending,
                    obscureText: true,
                    prefixIcon: AfriIcons.privacy,
                    maxLength: 6,
                    autofocus: !usesLargeText,
                    textInputAction: TextInputAction.done,
                    errorText: _otpError(l10n),
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    enableSuggestions: false,
                    autocorrect: false,
                    onSubmitted: (_) => _verifyCode(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriButton(
                    key: const ValueKey<String>('supporter-verify-otp-button'),
                    label: _isOnline
                        ? usesLargeText
                              ? l10n.authVerifyCode
                              : l10n.authVerifyAndContinue
                        : l10n.connectionRequired,
                    icon: AfriIcons.verified,
                    onTap: _verifyCode,
                    isLoading: _isVerifying,
                    enabled:
                        _isOnline &&
                        !_isVerifying &&
                        !_isResending &&
                        _canSubmitOtp,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            if (usesLargeText)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [resendAction, changeNumberAction],
              )
            else
              Row(
                children: [
                  Expanded(child: resendAction),
                  changeNumberAction,
                ],
              ),
          ],
        ),
      ),
    );
  }
}

const _offlinePhoneFailure = AuthActionFailure(
  kind: AuthActionFailureKind.offline,
  message: '',
);

const _offlineOtpFailure = AuthActionFailure(
  kind: AuthActionFailureKind.offline,
  message: '',
);

String _localizedPhoneFailureMessage(
  AfriLocalizations l10n,
  AuthActionFailureKind kind,
) {
  return switch (kind) {
    AuthActionFailureKind.permissionDenied => l10n.authPhonePermissionMessage,
    AuthActionFailureKind.securityTimeout => l10n.authPhoneTimeoutMessage,
    AuthActionFailureKind.conflict => l10n.authPhoneConflictMessage,
    AuthActionFailureKind.invalidInput => l10n.authPhoneInvalidMessage,
    AuthActionFailureKind.unknown => l10n.authPhoneUnknownMessage,
    AuthActionFailureKind.offline => l10n.authPhoneOfflineMessage,
  };
}

String _localizedOtpFailureMessage(
  AfriLocalizations l10n,
  AuthActionFailureKind kind,
) {
  return switch (kind) {
    AuthActionFailureKind.permissionDenied => l10n.authOtpPermissionMessage,
    AuthActionFailureKind.securityTimeout => l10n.authOtpExpiredMessage,
    AuthActionFailureKind.conflict => l10n.authOtpConflictMessage,
    AuthActionFailureKind.invalidInput => l10n.authOtpInvalidMessage,
    AuthActionFailureKind.unknown => l10n.authOtpUnknownMessage,
    AuthActionFailureKind.offline => l10n.authOtpOfflineMessage,
  };
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
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!usesLargeText) ...[
          Container(
            width: SizeTokens.iconXxl,
            height: SizeTokens.iconXxl,
            decoration: BoxDecoration(
              color: ColorTokens.primaryContainer,
              borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
              boxShadow: AfriShadows.primaryGlow(ColorTokens.primaryContainer),
            ),
            child: Icon(icon, color: ColorTokens.onSurface),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
        ],
        Text(
          eyebrow,
          style: TypographyTokens.labelMedium().copyWith(
            color: ColorTokens.primaryContainer,
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
