import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_onboarding/src/screens/supporter_phone_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/app_font_loader.dart';

const supporterPhoneAuthTestNumber = '+250700000001';
const supporterPhoneAuthTestOtp = '00000';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    this.verifyResult,
    this.requestError,
    this.verifyError,
    this.requestGate,
  }) : super(clubId: '24');

  final UserProfile? verifyResult;
  final Object? requestError;
  final Object? verifyError;
  final Completer<void>? requestGate;

  String? requestedPhone;
  supabase.OtpChannel? requestedChannel;
  String? verifiedPhone;
  String? verifiedToken;
  int requestCount = 0;

  @override
  Future<void> requestPhoneSignInOtp({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.sms,
    bool shouldCreateUser = true,
  }) async {
    requestCount += 1;
    requestedPhone = phone;
    requestedChannel = channel;
    if (requestGate case final gate?) {
      await gate.future;
    }
    if (requestError case final error?) {
      throw error;
    }
  }

  @override
  Future<UserProfile> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) async {
    verifiedPhone = phone;
    verifiedToken = token;
    if (verifyError case final error?) {
      throw error;
    }
    if (verifyResult == null) {
      throw Exception('Missing fake verify result.');
    }
    return verifyResult!;
  }

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/auth/phone',
    routes: [
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const SupporterPhoneAuthScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => const SupporterOtpVerificationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Route')),
      ),
    ],
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeAuthRepository repository,
  Locale appLocale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: AfriLocalizationsScope(
        locale: appLocale,
        child: MaterialApp.router(routerConfig: _buildRouter()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    AfriCountryCatalog.withCountries(await loadBuiltInCountries());
  });
  tearDownAll(() => AfriCountryCatalog.withCountries([]));
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('keeps the primary action at the bottom and above the keyboard', (
    tester,
  ) async {
    await _pumpApp(tester, repository: _FakeAuthRepository());
    final submit = find.byKey(
      const ValueKey<String>('supporter-send-otp-button'),
    );
    final input = find.byKey(const ValueKey<String>('supporter-phone-input'));
    expect(tester.getRect(submit).bottom, closeTo(828, 1));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    _expectInKeyboardViewport(tester, input);
    _expectInKeyboardViewport(tester, submit);
    expect(tester.getRect(submit).bottom, closeTo(528, 1));
  });

  testWidgets(
    'splits a pasted country code without changing the OTP recipient',
    (tester) async {
      final repository = _FakeAuthRepository();
      await _pumpApp(tester, repository: repository);
      final input = find.byKey(const ValueKey<String>('supporter-phone-input'));
      await tester.enterText(input, supporterPhoneAuthTestNumber);
      await tester.pumpAndSettle();
      expect(tester.widget<AfriInputField>(input).controller.text, '700000001');
      expect(find.textContaining('+250'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('supporter-send-otp-button')),
      );
      await tester.pumpAndSettle();
      expect(repository.requestedPhone, supporterPhoneAuthTestNumber);
      expect(repository.requestedChannel, supabase.OtpChannel.whatsapp);
    },
  );

  testWidgets('country selection normalizes a national phone number once', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository: repository);
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-phone-country')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Uganda').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('supporter-phone-input')),
      '772000001',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-send-otp-button')),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedPhone, '+256772000001');
    expect(repository.requestCount, 1);
  });

  testWidgets('retains international numbers outside the country catalogue', (
    tester,
  ) async {
    const international = '+447700900001';
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository: repository);
    final input = find.byKey(const ValueKey<String>('supporter-phone-input'));
    await tester.enterText(input, international);
    await tester.pumpAndSettle();
    expect(tester.widget<AfriInputField>(input).controller.text, international);
    expect(
      find.byKey(const ValueKey<String>('supporter-phone-country')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-send-otp-button')),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedPhone, international);
    expect(repository.requestCount, 1);
  });

  testWidgets('requests OTP using the WhatsApp delivery channel', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('supporter-phone-input')),
      supporterPhoneAuthTestNumber,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-send-otp-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.requestedPhone, supporterPhoneAuthTestNumber);
    expect(repository.requestedChannel, supabase.OtpChannel.whatsapp);
    expect(find.byType(SupporterOtpVerificationScreen), findsOneWidget);
  });

  testWidgets('blocks duplicate OTP requests while retaining the phone draft', (
    tester,
  ) async {
    final requestGate = Completer<void>();
    final repository = _FakeAuthRepository(requestGate: requestGate);
    await _pumpApp(tester, repository: repository);

    final phoneField = find.byKey(
      const ValueKey<String>('supporter-phone-input'),
    );
    final submit = find.byKey(
      const ValueKey<String>('supporter-send-otp-button'),
    );
    await tester.enterText(phoneField, supporterPhoneAuthTestNumber);
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();

    expect(repository.requestCount, 1);
    expect(tester.widget<AfriButton>(submit).enabled, isFalse);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: phoneField, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      '700000001',
    );

    requestGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SupporterOtpVerificationScreen), findsOneWidget);
  });

  testWidgets('verifies OTP and continues into the supporter app', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      verifyResult: const UserProfile(
        id: 'supporter-1',
        clubId: '24',
        publicUserId: '483912',
        momoNumber: supporterPhoneAuthTestNumber,
      ),
    );
    await _pumpApp(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('supporter-phone-input')),
      supporterPhoneAuthTestNumber,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-send-otp-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey<String>('supporter-phone-otp-input')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('supporter-phone-otp-input')),
      supporterPhoneAuthTestOtp,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-verify-otp-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.verifiedPhone, supporterPhoneAuthTestNumber);
    expect(repository.verifiedToken, supporterPhoneAuthTestOtp);
    expect(find.text('Home Route'), findsOneWidget);
  });

  testWidgets('keeps the focused phone field visible above the keyboard', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _FakeAuthRepository(
      requestError: StateError('WhatsApp delivery unavailable'),
    );

    await _pumpApp(tester, repository: repository);
    final phoneField = find.byKey(
      const ValueKey<String>('supporter-phone-input'),
    );
    final submit = find.byKey(
      const ValueKey<String>('supporter-send-otp-button'),
    );
    await tester.showKeyboard(phoneField);
    await tester.enterText(phoneField, supporterPhoneAuthTestNumber);
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(AfriScreenScaffold), findsOneWidget);
    expect(tester.getRect(phoneField).bottom, lessThanOrEqualTo(852 - 320));
    final failureState = find.byKey(
      const ValueKey<String>('supporter-phone-state'),
    );
    expect(failureState, findsOneWidget);
    await tester.ensureVisible(failureState);
    await tester.ensureVisible(submit);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps OTP entry and verification above the keyboard', (
    tester,
  ) async {
    await _pumpApp(tester, repository: _FakeAuthRepository());
    await tester.enterText(
      find.byKey(const ValueKey<String>('supporter-phone-input')),
      supporterPhoneAuthTestNumber,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('supporter-send-otp-button')),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final input = find.byKey(
      const ValueKey<String>('supporter-phone-otp-input'),
    );
    final submit = find.byKey(
      const ValueKey<String>('supporter-verify-otp-button'),
    );
    _expectInKeyboardViewport(tester, input);
    _expectInKeyboardViewport(tester, submit);
    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(852 - 320 - 16));
    expect(submit.hitTestable(), findsOneWidget);
  });

  testWidgets(
    'resend cooldown preserves the draft and prevents repeated sends',
    (tester) async {
      final repository = _FakeAuthRepository();
      await _pumpApp(tester, repository: repository);
      await tester.enterText(
        find.byKey(const ValueKey<String>('supporter-phone-input')),
        supporterPhoneAuthTestNumber,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('supporter-send-otp-button')),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(
        const ValueKey<String>('supporter-phone-otp-input'),
      );
      final resend = find.byKey(
        const ValueKey<String>('supporter-resend-otp-button'),
      );
      await tester.enterText(input, supporterPhoneAuthTestOtp);
      await tester.pumpAndSettle();
      expect(tester.widget<AfriTextButton>(resend).onPressed, isNull);
      await tester.pump(const Duration(seconds: 61));
      await tester.tap(resend);
      await tester.pumpAndSettle();
      expect(repository.requestCount, 2);
      expect(repository.requestedChannel, supabase.OtpChannel.whatsapp);
      expect(
        tester.widget<AfriCodeInput>(input).controller.text,
        supporterPhoneAuthTestOtp,
      );
      expect(tester.widget<AfriTextButton>(resend).onPressed, isNull);
    },
  );

  testWidgets(
    'keyboard-open auth keeps the active field, error, and submit reachable',
    (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      final repository = _FakeAuthRepository(
        requestError: StateError('WhatsApp delivery unavailable'),
      );

      await _pumpApp(tester, repository: repository);
      final phoneField = find.byKey(
        const ValueKey<String>('supporter-phone-input'),
      );
      final submit = find.byKey(
        const ValueKey<String>('supporter-send-otp-button'),
      );
      await tester.showKeyboard(phoneField);
      await tester.enterText(phoneField, supporterPhoneAuthTestNumber);
      await tester.pump();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final failureState = find.byKey(
        const ValueKey<String>('supporter-phone-state'),
      );
      expect(failureState, findsOneWidget);
      await tester.ensureVisible(failureState);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, failureState);
      await tester.ensureVisible(phoneField);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, phoneField);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, submit);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in <String, Size>{
    'standard landscape': const Size(852, 393),
    'compact-height landscape': const Size(720, 320),
  }.entries) {
    testWidgets('${profile.key} keeps auth input, error, and submit usable', (
      tester,
    ) async {
      tester.view.physicalSize = profile.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeAuthRepository(
        requestError: StateError('WhatsApp delivery unavailable'),
      );

      await _pumpApp(tester, repository: repository);
      final phoneField = find.byKey(
        const ValueKey<String>('supporter-phone-input'),
      );
      final submit = find.byKey(
        const ValueKey<String>('supporter-send-otp-button'),
      );
      await tester.enterText(phoneField, supporterPhoneAuthTestNumber);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final failureState = find.byKey(
        const ValueKey<String>('supporter-phone-state'),
      );
      expect(failureState, findsOneWidget);
      await tester.ensureVisible(failureState);
      await tester.ensureVisible(phoneField);
      await tester.ensureVisible(submit);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preserves phone draft and auth route across resize and resume', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository: repository);

    final phoneField = find.byKey(
      const ValueKey<String>('supporter-phone-input'),
    );
    await tester.enterText(phoneField, supporterPhoneAuthTestNumber);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: phoneField,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '700000001',
    );

    tester.view.physicalSize = const Size(852, 393);
    await tester.pumpAndSettle();
    expect(find.byType(SupporterPhoneAuthScreen), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: phoneField,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '700000001',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(SupporterPhoneAuthScreen), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: phoneField,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '700000001',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'announces request failure, retains the phone, and exposes phone autofill',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeAuthRepository(
        requestError: StateError('WhatsApp delivery unavailable'),
      );
      await _pumpApp(tester, repository: repository);

      final phoneField = find.byKey(
        const ValueKey<String>('supporter-phone-input'),
      );
      await tester.enterText(phoneField, supporterPhoneAuthTestNumber);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('supporter-send-otp-button')),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.descendant(of: phoneField, matching: find.byType(TextField)),
      );
      expect(textField.controller?.text, '700000001');
      expect(textField.autofillHints, contains(AutofillHints.telephoneNumber));
      final error = tester.widget<AfriInputField>(phoneField).errorText;
      expect(error, isNull);
      final failureState = find.byKey(
        const ValueKey<String>('supporter-phone-state'),
      );
      expect(failureState, findsOneWidget);
      expect(
        tester.getSemantics(failureState).label,
        contains('Code not sent'),
      );
      expect(find.byType(SupporterPhoneAuthScreen), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'announces verification failure, retains the code, and exposes OTP autofill',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeAuthRepository(
        verifyError: StateError('Verification code expired'),
      );
      await _pumpApp(tester, repository: repository);

      await tester.enterText(
        find.byKey(const ValueKey<String>('supporter-phone-input')),
        supporterPhoneAuthTestNumber,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('supporter-send-otp-button')),
      );
      await tester.pumpAndSettle();

      final otpField = find.byKey(
        const ValueKey<String>('supporter-phone-otp-input'),
      );
      await tester.enterText(otpField, supporterPhoneAuthTestOtp);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('supporter-verify-otp-button')),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(
        find.descendant(of: otpField, matching: find.byType(TextField)),
      );
      expect(textField.controller?.text, supporterPhoneAuthTestOtp);
      expect(textField.autofillHints, contains(AutofillHints.oneTimeCode));
      final error = tester.widget<AfriCodeInput>(otpField).errorText;
      expect(error, isNotNull);
      expect(error, 'Request a new code.');
      expect(
        find.bySemanticsLabel('WhatsApp code. Error: $error'),
        findsOneWidget,
      );
      expect(find.byType(SupporterOtpVerificationScreen), findsOneWidget);
      semantics.dispose();
    },
  );

  for (final locale in const <Locale>[Locale('en')]) {
    testWidgets('renders phone and OTP tasks in ${locale.languageCode}', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      final l10n = lookupAfriLocalizations(locale);
      await _pumpApp(tester, repository: repository, appLocale: locale);

      expect(find.text(l10n.authEnterNumberTitle), findsOneWidget);
      expect(find.text(l10n.authPhonePrivacy), findsOneWidget);
      expect(find.text(l10n.authSendCode), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('supporter-phone-input')),
        supporterPhoneAuthTestNumber,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('supporter-send-otp-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.authEnterCodeTitle), findsOneWidget);
      expect(find.text(l10n.authCodePrivacy), findsOneWidget);
      expect(find.text(l10n.authVerifyAndContinue), findsOneWidget);
    });
  }
}

void _expectInKeyboardViewport(WidgetTester tester, Finder finder) {
  final visibleBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
      tester.view.viewInsets.bottom;
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
}
