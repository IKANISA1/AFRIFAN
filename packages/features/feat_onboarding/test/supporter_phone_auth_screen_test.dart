import 'package:core_auth/core_auth.dart';
import 'package:feat_onboarding/src/screens/supporter_phone_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/design_font_loader.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.verifyResult}) : super(clubId: '24');

  final UserProfile? verifyResult;

  String? requestedPhone;
  supabase.OtpChannel? requestedChannel;
  String? verifiedPhone;
  String? verifiedToken;

  @override
  Future<void> requestPhoneSignInOtp({
    required String phone,
    supabase.OtpChannel channel = supabase.OtpChannel.sms,
    bool shouldCreateUser = true,
  }) async {
    requestedPhone = phone;
    requestedChannel = channel;
  }

  @override
  Future<UserProfile> verifyPhoneSignInOtp({
    required String phone,
    required String token,
  }) async {
    verifiedPhone = phone;
    verifiedToken = token;
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
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: _buildRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

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

  testWidgets('verifies OTP and continues into the supporter app', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      verifyResult: const UserProfile(
        id: 'supporter-1',
        clubId: '24',
        publicUserId: '483912',
        phone: supporterPhoneAuthTestNumber,
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
}
