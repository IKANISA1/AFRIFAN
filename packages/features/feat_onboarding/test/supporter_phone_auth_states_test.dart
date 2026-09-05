import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_onboarding/src/screens/supporter_phone_auth_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

const supporterPhoneAuthTestNumber = '+250700000001';
const supporterPhoneAuthTestOtp = '00000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    AfriCountryCatalog.withCountries(await loadBuiltInCountries());
  });
  tearDownAll(() => AfriCountryCatalog.withCountries([]));

  for (final state in _AuthGoldenState.values) {
    testWidgets('golden phone auth ${state.id} state', (tester) async {
      final requestGate =
          state == _AuthGoldenState.loading || state == _AuthGoldenState.syncing
          ? Completer<void>()
          : null;
      final repository = _GoldenAuthRepository(
        requestGate: requestGate,
        requestError: switch (state) {
          _AuthGoldenState.error => StateError('backend request exploded'),
          _AuthGoldenState.permissionDenied => StateError(
            'permission denied by policy',
          ),
          _AuthGoldenState.conflict => StateError('phone already linked'),
          _AuthGoldenState.securityTimeout => StateError('request timed out'),
          _ => null,
        },
      );
      addTearDown(() {
        if (requestGate != null && !requestGate.isCompleted) {
          requestGate.complete();
        }
      });
      final connectivity = ValueNotifier<bool>(
        state != _AuthGoldenState.offline,
      );
      addTearDown(connectivity.dispose);

      await _pumpAuthGolden(
        tester,
        route: _AuthGoldenRoute.phone,
        state: state,
        repository: repository,
        connectivity: connectivity,
      );
      await _preparePhoneState(tester, state);
      await _captureAuthGolden(
        tester,
        route: _AuthGoldenRoute.phone,
        state: state,
      );
    });

    testWidgets('golden OTP auth ${state.id} state', (tester) async {
      final verifyGate = state == _AuthGoldenState.loading
          ? Completer<void>()
          : null;
      final requestGate = state == _AuthGoldenState.syncing
          ? Completer<void>()
          : null;
      final repository = _GoldenAuthRepository(
        requestGate: requestGate,
        verifyGate: verifyGate,
        verifyError: switch (state) {
          _AuthGoldenState.error => StateError('invalid otp'),
          _AuthGoldenState.permissionDenied => StateError(
            'permission denied by policy',
          ),
          _AuthGoldenState.conflict => StateError('phone already linked'),
          _AuthGoldenState.securityTimeout => StateError(
            'verification code expired',
          ),
          _ => null,
        },
      );
      addTearDown(() {
        if (requestGate != null && !requestGate.isCompleted) {
          requestGate.complete();
        }
        if (verifyGate != null && !verifyGate.isCompleted) {
          verifyGate.complete();
        }
      });
      final connectivity = ValueNotifier<bool>(
        state != _AuthGoldenState.offline,
      );
      addTearDown(connectivity.dispose);

      await _pumpAuthGolden(
        tester,
        route: _AuthGoldenRoute.otp,
        state: state,
        repository: repository,
        connectivity: connectivity,
      );
      await _prepareOtpState(tester, state);
      await _captureAuthGolden(
        tester,
        route: _AuthGoldenRoute.otp,
        state: state,
      );
    });
  }
}

enum _AuthGoldenRoute { phone, otp }

enum _AuthGoldenState {
  loading,
  empty,
  error,
  offline,
  permissionDenied,
  disabled,
  focused,
  pressed,
  selected,
  largeText,
  reducedMotion,
  dark,
  light,
  syncing,
  conflict,
  securityTimeout;

  String get id => switch (this) {
    loading => 'loading',
    empty => 'empty',
    error => 'error',
    offline => 'offline',
    permissionDenied => 'permission_denied',
    disabled => 'disabled',
    focused => 'focused',
    pressed => 'pressed',
    selected => 'selected',
    largeText => 'large_text',
    reducedMotion => 'reduced_motion',
    dark => 'dark',
    light => 'light',
    syncing => 'syncing',
    conflict => 'conflict',
    securityTimeout => 'security_timeout',
  };
}

Future<void> _pumpAuthGolden(
  WidgetTester tester, {
  required _AuthGoldenRoute route,
  required _AuthGoldenState state,
  required _GoldenAuthRepository repository,
  required ValueListenable<bool> connectivity,
}) async {
  final size = state == _AuthGoldenState.largeText
      ? const Size(320, 720)
      : const Size(390, 844);
  final brightness = state == _AuthGoldenState.light
      ? Brightness.light
      : Brightness.dark;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue =
      state == _AuthGoldenState.largeText ? 2 : 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  TypographyTokens.debugUseFallbackFonts = true;
  ColorTokens.setBrightness(brightness);
  addTearDown(() {
    TypographyTokens.debugUseFallbackFonts = false;
    ColorTokens.setBrightness(Brightness.dark);
  });

  final initialLocation = route == _AuthGoldenRoute.phone
      ? '/auth/phone'
      : Uri(
          path: '/auth/otp',
          queryParameters: const <String, String>{'phone': '+250700000001'},
        ).toString();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) =>
            SupporterPhoneAuthScreen(connectivity: connectivity),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, routeState) => SupporterOtpVerificationScreen(
          connectivity: connectivity,
          resendCooldown: state == _AuthGoldenState.syncing
              ? Duration.zero
              : const Duration(seconds: 60),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: MaterialApp.router(
          theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
          routerConfig: router,
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey<String>('auth-state-golden'),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _preparePhoneState(
  WidgetTester tester,
  _AuthGoldenState state,
) async {
  final input = find.byKey(const ValueKey<String>('supporter-phone-input'));
  final submit = find.byKey(
    const ValueKey<String>('supporter-send-otp-button'),
  );

  switch (state) {
    case _AuthGoldenState.loading:
    case _AuthGoldenState.error:
    case _AuthGoldenState.permissionDenied:
    case _AuthGoldenState.conflict:
    case _AuthGoldenState.securityTimeout:
    case _AuthGoldenState.syncing:
      await tester.enterText(input, supporterPhoneAuthTestNumber);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 350));
      if (state != _AuthGoldenState.loading &&
          state != _AuthGoldenState.syncing) {
        await tester.pumpAndSettle();
      }
    case _AuthGoldenState.disabled:
      await tester.enterText(input, '+250 7');
      await tester.pump();
      expect(tester.widget<AfriButton>(submit).enabled, isFalse);
    case _AuthGoldenState.focused:
      await tester.enterText(input, '+250 7xx xxx xxx');
      await tester.tap(input);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'WhatsApp number');
    case _AuthGoldenState.pressed:
      await tester.enterText(input, '000000000');
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(submit));
      addTearDown(gesture.cancel);
      await tester.pump();
    case _AuthGoldenState.selected:
      await tester.enterText(input, '+250 7xx xxx xxx');
      final textField = tester.widget<TextField>(
        find.descendant(of: input, matching: find.byType(TextField)),
      );
      final selectedText = textField.controller!.text;
      await tester.tap(input);
      textField.controller!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: selectedText.length,
      );
      await tester.pump();
      expect(textField.controller!.selection.extentOffset, selectedText.length);
    case _AuthGoldenState.empty:
    case _AuthGoldenState.offline:
    case _AuthGoldenState.reducedMotion:
    case _AuthGoldenState.dark:
    case _AuthGoldenState.light:
      break;
    case _AuthGoldenState.largeText:
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .pixels,
        0,
      );
  }

  switch (state) {
    case _AuthGoldenState.loading:
      expect(find.text('Sending code'), findsOneWidget);
    case _AuthGoldenState.error:
      expect(find.text('Code not sent'), findsOneWidget);
    case _AuthGoldenState.offline:
      expect(find.text('Connection required'), findsWidgets);
    case _AuthGoldenState.permissionDenied:
      expect(find.text('Sign-in unavailable'), findsOneWidget);
    case _AuthGoldenState.conflict:
      expect(find.text('Number already linked'), findsOneWidget);
    case _AuthGoldenState.securityTimeout:
      expect(find.text('Request timed out'), findsOneWidget);
    case _AuthGoldenState.syncing:
      expect(find.text('Sending code'), findsOneWidget);
    case _AuthGoldenState.empty:
    case _AuthGoldenState.disabled:
      expect(tester.widget<AfriButton>(submit).enabled, isFalse);
    case _AuthGoldenState.focused:
    case _AuthGoldenState.pressed:
    case _AuthGoldenState.selected:
    case _AuthGoldenState.largeText:
    case _AuthGoldenState.reducedMotion:
    case _AuthGoldenState.dark:
    case _AuthGoldenState.light:
      break;
  }
}

Future<void> _prepareOtpState(
  WidgetTester tester,
  _AuthGoldenState state,
) async {
  final input = find.byKey(const ValueKey<String>('supporter-phone-otp-input'));
  final submit = find.byKey(
    const ValueKey<String>('supporter-verify-otp-button'),
  );

  switch (state) {
    case _AuthGoldenState.loading:
    case _AuthGoldenState.error:
    case _AuthGoldenState.permissionDenied:
    case _AuthGoldenState.conflict:
    case _AuthGoldenState.securityTimeout:
      await tester.enterText(input, supporterPhoneAuthTestOtp);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 350));
      if (state != _AuthGoldenState.loading) {
        await tester.pumpAndSettle();
      }
    case _AuthGoldenState.disabled:
      await tester.enterText(input, '12');
      await tester.pump();
      expect(tester.widget<AfriButton>(submit).enabled, isFalse);
    case _AuthGoldenState.focused:
      await tester.enterText(input, '123');
      await tester.tap(input);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'WhatsApp code');
    case _AuthGoldenState.pressed:
      await tester.enterText(input, supporterPhoneAuthTestOtp);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(submit));
      addTearDown(gesture.cancel);
      await tester.pump();
    case _AuthGoldenState.selected:
      await tester.enterText(input, '123');
      final textField = tester.widget<TextField>(
        find.descendant(of: input, matching: find.byType(TextField)),
      );
      final selectedText = textField.controller!.text;
      await tester.tap(input);
      textField.controller!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: selectedText.length,
      );
      await tester.pump();
      expect(textField.controller!.selection.extentOffset, selectedText.length);
    case _AuthGoldenState.syncing:
      await tester.tap(find.text('Resend code'));
      await tester.pump(const Duration(milliseconds: 350));
    case _AuthGoldenState.empty:
    case _AuthGoldenState.offline:
    case _AuthGoldenState.reducedMotion:
    case _AuthGoldenState.dark:
    case _AuthGoldenState.light:
      break;
    case _AuthGoldenState.largeText:
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .pixels,
        0,
      );
  }

  switch (state) {
    case _AuthGoldenState.loading:
      expect(find.text('Checking code'), findsOneWidget);
    case _AuthGoldenState.error:
      expect(find.text('Code not accepted'), findsOneWidget);
    case _AuthGoldenState.offline:
      expect(find.text('Connection required'), findsWidgets);
    case _AuthGoldenState.permissionDenied:
      expect(find.text('Verification unavailable'), findsOneWidget);
    case _AuthGoldenState.conflict:
      expect(find.text('Number already linked'), findsOneWidget);
    case _AuthGoldenState.securityTimeout:
      expect(find.text('Code expired'), findsOneWidget);
    case _AuthGoldenState.syncing:
      expect(find.text('Sending new code'), findsOneWidget);
    case _AuthGoldenState.empty:
    case _AuthGoldenState.disabled:
      expect(tester.widget<AfriButton>(submit).enabled, isFalse);
    case _AuthGoldenState.focused:
    case _AuthGoldenState.pressed:
    case _AuthGoldenState.selected:
    case _AuthGoldenState.largeText:
    case _AuthGoldenState.reducedMotion:
    case _AuthGoldenState.dark:
    case _AuthGoldenState.light:
      break;
  }
}

Future<void> _captureAuthGolden(
  WidgetTester tester, {
  required _AuthGoldenRoute route,
  required _AuthGoldenState state,
}) async {
  expect(tester.takeException(), isNull);
  if (route == _AuthGoldenRoute.phone &&
      (state == _AuthGoldenState.dark || state == _AuthGoldenState.light)) {
    final action = find.byKey(
      const ValueKey<String>('supporter-send-otp-button'),
    );
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(844));
    expect(action.hitTestable(), findsOneWidget);
  }
  final viewport = state == _AuthGoldenState.largeText ? '320x720' : '390x844';
  final theme = state == _AuthGoldenState.light ? 'light' : 'dark';
  await expectLater(
    find.byKey(const ValueKey<String>('auth-state-golden')),
    matchesGoldenFile(
      'goldens/auth_${route.name}_state_${state.id}_${theme}_$viewport.png',
    ),
  );
}

class _GoldenAuthRepository extends AuthRepository {
  _GoldenAuthRepository({
    this.requestGate,
    this.verifyGate,
    this.requestError,
    this.verifyError,
  }) : super(clubId: '24');

  final Completer<void>? requestGate;
  final Completer<void>? verifyGate;
  final Object? requestError;
  final Object? verifyError;

  @override
  Future<void> requestPhoneSignInOtp({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.sms,
    bool shouldCreateUser = true,
  }) async {
    if (requestGate case final gate?) await gate.future;
    if (requestError case final error?) throw error;
  }

  @override
  Future<UserProfile> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) async {
    if (verifyGate case final gate?) await gate.future;
    if (verifyError case final error?) throw error;
    return const UserProfile(
      id: 'supporter-golden',
      clubId: '24',
      publicUserId: '000000',
    );
  }

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}
