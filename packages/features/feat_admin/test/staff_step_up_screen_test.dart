import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/src/screens/admin_route_guard.dart';
import 'package:feat_admin/src/screens/staff_step_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:test_support/app_font_loader.dart';
import '../../../core/core_auth/test/staff_step_up_test.dart' show staffSession;

class StaffAuth extends AuthNotifier {
  @override
  AuthState build() => AuthAuthenticated(
    profile: const UserProfile(id: 'staff', clubId: '24'),
    workspace: AdminWorkspaceAccess.fromRpcResponse({
      'has_platform_access': true,
    }),
  );
  @override
  Future<void> refreshAdminAccess() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() => TypographyTokens.debugUseFallbackFonts = false);
  for (final enrolled in [true, false]) {
    testWidgets(
      'staff actual ${enrolled ? 'challenge' : 'enrollment'} gates child until SDK verification and SQL grant',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final requests = <http.Request>[];
        bool verified = false;
        final client = (await tester.runAsync(
          () async => sb.SupabaseClient(
            'https://auth.test',
            'local-test',
            authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((r) async {
              requests.add(r);
              Object body;
              if (r.url.path.endsWith('/user')) {
                final user = Map<String, dynamic>.from(
                  staffSession(aal: 'aal1')['user'],
                );
                user['factors'] = enrolled
                    ? [
                        {
                          'id': 'verified-factor',
                          'friendly_name': 'Authenticator',
                          'factor_type': 'totp',
                          'status': 'verified',
                          'created_at': '2026-10-01T00:00:00Z',
                          'updated_at': '2026-10-01T00:00:00Z',
                        },
                      ]
                    : [];
                body = user;
              } else if (r.url.path.endsWith('/factors')) {
                body = {
                  'id': 'new-factor',
                  'type': 'totp',
                  'totp': {
                    'qr_code': '<svg/>',
                    'secret': 'VOLATILE_SETUP_KEY',
                    'uri': 'otpauth://totp/test',
                  },
                };
              } else if (r.url.path.endsWith('/challenge')) {
                body = {
                  'id': 'challenge',
                  'type': 'totp',
                  'expires_at':
                      DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
                };
              } else if (r.url.path.endsWith('/verify')) {
                expect(jsonDecode(r.body)['code'], '123456');
                verified = true;
                body = staffSession();
              } else if (r.url.path.endsWith('/staff_step_up_allowed')) {
                body = verified;
              } else {
                throw StateError(
                  'Unexpected actual caller request ${r.url.path}',
                );
              }
              return http.Response(
                jsonEncode(body),
                200,
                request: r,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(client.dispose);
        });
        await tester.runAsync(
          () =>
              client.auth.recoverSession(jsonEncode(staffSession(aal: 'aal1'))),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseClientProvider.overrideWithValue(client),
              authStateProvider.overrideWith(StaffAuth.new),
            ],
            child: RepaintBoundary(
              key: const ValueKey('staff-evidence'),
              child: MaterialApp(
                theme: ClubTheme.from(ClubConfig.fallback()),
                debugShowCheckedModeBanner: false,
                home: const AdminRouteGuard(
                  child: Text('PROTECTED STAFF ACTION'),
                ),
              ),
            ),
          ),
        );

        await _finishRequests(tester);

        expect(find.text('PROTECTED STAFF ACTION'), findsNothing);
        expect(
          find.byKey(ValueKey(enrolled ? 'staff-totp-code' : 'staff-enroll')),
          findsOneWidget,
          reason: requests.map((r) => r.url.path).join(','),
        );
        await _capture(
          tester,
          enrolled ? 'staff-totp-challenge' : 'staff-totp-enrollment',
        );
        if (!enrolled) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('staff-enroll')),
          );
          await tester.tap(find.byKey(const ValueKey('staff-enroll')));

          await _finishRequests(tester);

          expect(find.text('VOLATILE_SETUP_KEY'), findsOneWidget);
          await _capture(tester, 'staff-totp-setup');
          tester.view.physicalSize = const Size(320, 760);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          await tester.pump();
          await _capture(tester, 'staff-totp-setup-compact-large-text');
          await tester.ensureVisible(
            find.byKey(const ValueKey('staff-verify')),
          );
          await tester.pump();
          final codeLabel = tester.renderObject<RenderParagraph>(
            find.byKey(const ValueKey('staff-totp-label')),
          );
          expect(codeLabel.didExceedMaxLines, isFalse);
          final recoveryLabel = tester.renderObject<RenderParagraph>(
            find.text('Back to settings'),
          );
          expect(recoveryLabel.didExceedMaxLines, isFalse);
          await tester.ensureVisible(find.text('Back to settings'));
          await tester.pump();
          await _capture(
            tester,
            'staff-totp-setup-compact-large-text-controls',
          );
          expect(tester.takeException(), isNull);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.view.physicalSize = const Size(390, 844);
          await tester.pump();
          final enrollment = requests.singleWhere(
            (r) => r.url.path.endsWith('/factors'),
          );
          expect(jsonDecode(enrollment.body)['factor_type'], 'totp');
          expect(enrollment.headers['authorization'], startsWith('Bearer '));
        }
        await tester.enterText(
          find.byKey(const ValueKey('staff-totp-code')),
          '123456',
        );
        await tester.pump();
        final verify = find.byKey(const ValueKey('staff-verify'));
        await tester.ensureVisible(verify);
        await tester.tap(verify);

        await _finishRequests(tester);

        expect(find.text('PROTECTED STAFF ACTION'), findsOneWidget);
        expect(find.text('VOLATILE_SETUP_KEY'), findsNothing);
        expect(
          requests.where((r) => r.url.path.endsWith('/challenge')).length,
          1,
        );
        expect(requests.where((r) => r.url.path.endsWith('/verify')).length, 1);
        expect(requests.last.url.path, endsWith('/staff_step_up_allowed'));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AdminRouteGuard)),
        );
        verified = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('PROTECTED STAFF ACTION'), findsNothing);
        await _finishRequests(tester);
        expect(find.text('PROTECTED STAFF ACTION'), findsNothing);
        verified = true;
        final refresh = container.read(staffStepUpProvider.notifier).refresh();
        await tester.runAsync(() => refresh);
        await tester.pump();
        expect(find.text('PROTECTED STAFF ACTION'), findsOneWidget);
        await tester.pump(const Duration(seconds: 301));
        expect(find.text('PROTECTED STAFF ACTION'), findsNothing);
      },
    );
  }
  testWidgets(
    'staff setup key and code are cleared by an actual SDK account switch',
    (tester) async {
      late sb.SupabaseClient client;
      client = (await tester.runAsync(
        () async => sb.SupabaseClient(
          'https://auth.test',
          'local-test',
          authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
            final Object body = r.url.path.endsWith('/user')
                ? staffSession(user: client.auth.currentUser!.id)['user']
                : {
                    'id': 'new-factor',
                    'type': 'totp',
                    'totp': {
                      'qr_code': '<svg/>',
                      'secret': 'VOLATILE_SETUP_KEY',
                      'uri': 'otpauth://totp/test',
                    },
                  };
            return http.Response(
              jsonEncode(body),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(client.dispose);
      });
      await tester.runAsync(
        () => client.auth.recoverSession(jsonEncode(staffSession(aal: 'aal1'))),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [supabaseClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            theme: ClubTheme.from(ClubConfig.fallback()),
            debugShowCheckedModeBanner: false,
            home: const StaffStepUpScreen(),
          ),
        ),
      );
      await _finishRequests(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('staff-enroll')));
      await tester.tap(find.byKey(const ValueKey('staff-enroll')));
      await _finishRequests(tester);
      expect(find.text('VOLATILE_SETUP_KEY'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('staff-totp-code')),
        '123456',
      );
      await tester.runAsync(
        () => client.auth.recoverSession(
          jsonEncode(staffSession(user: 'replacement', aal: 'aal1')),
        ),
      );
      await _finishRequests(tester);
      expect(client.auth.currentUser?.id, 'replacement');
      expect(find.text('VOLATILE_SETUP_KEY'), findsNothing);
      expect(find.byKey(const ValueKey('staff-totp-code')), findsNothing);
      expect(find.byKey(const ValueKey('staff-enroll')), findsOneWidget);
    },
  );
  testWidgets(
    'staff route does not grant access to cached metadata-only profile',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authStateProvider.overrideWith(FanAuth.new)],
          child: const MaterialApp(
            home: AdminRouteGuard(child: Text('PROTECTED STAFF ACTION')),
          ),
        ),
      );
      await _finishRequests(tester);
      expect(find.text('PROTECTED STAFF ACTION'), findsNothing);
      expect(find.text('Admin access required'), findsOneWidget);
    },
  );
}

class FanAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthAuthenticated(
    profile: UserProfile(id: 'fan', clubId: '24', isAdmin: true),
  );
  @override
  Future<void> refreshAdminAccess() async {}
}

Future<void> _finishRequests(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('staff-evidence')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory(
      '/Volumes/PRO-G40/Projects/Recovered-G-PRO/AFRICLUB/output/remediation-2026-10-01/staff-mfa-native-evidence',
    );
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
