import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/native_supporter_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core_auth/test/native_identity/support.dart' as auth;
import 'native_supporter_journey_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = lookupAfriLocalizations(const Locale('en'));
  setUp(() {
    ColorTokens.init();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() => TypographyTokens.debugUseFallbackFonts = false);

  JourneyFixture fixture() {
    final f = JourneyFixture();
    addTearDown(f.journey.dispose);
    return f;
  }

  Future<GoRouter> show(WidgetTester tester, JourneyFixture f) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/membership/native',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: Row(
              children: [
                Expanded(
                  child: AfriButton(
                    label: 'Home tab',
                    onTap: () => shell.goBranch(0),
                  ),
                ),
                Expanded(
                  child: AfriButton(
                    label: 'Membership tab',
                    onTap: () => shell.goBranch(1),
                  ),
                ),
              ],
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (_, _) => const Text('Home')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/membership/native',
                  builder: (_, _) => NativeMembershipJourneyScreen(
                    configuredClubId: '24',
                    journey: f.journey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ClubTheme.from(ClubConfig.fallback()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'retained tab exit hides identity and review synchronously without retry or revocation',
    (tester) async {
      final f = fixture();
      await f.review();
      f.journey.showConfirmation();
      final router = await show(tester, f);
      final screenState = tester.state(
        find.byType(NativeMembershipJourneyScreen),
      );
      await tester.ensureVisible(find.byType(AfriCheckbox));
      await tester.tap(find.byType(AfriCheckbox));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriButton>(
              find.widgetWithText(AfriButton, l.nativeMembershipOpenDialer),
            )
            .enabled,
        isTrue,
      );
      final journals = Map<String, String>.from(f.channel.values);
      expect(journals, isNotEmpty);
      final identityCalls = f.identity.transport.requests.length;
      final membershipCalls = f.transport.requests.length;
      await tester.tap(find.text('Home tab'));
      // The notification runs inside goBranch, before rendering the new frame.
      expect(f.journey.identity, isNull);
      expect(f.journey.paymentReview, isNull);
      expect(f.journey.stage, NativeMembershipStage.signedOut);
      expect(f.channel.values, journals);
      expect(f.identity.transport.requests.length, identityCalls);
      expect(f.transport.requests.length, membershipCalls);
      expect(f.dialer.opens, 0);
      await tester.pumpAndSettle();
      expect(find.byType(NativeMembershipJourneyScreen), findsNothing);
      expect(
        tester.state(
          find.byType(NativeMembershipJourneyScreen, skipOffstage: false),
        ),
        same(screenState),
      );
      await tester.tap(find.text('Membership tab'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/membership/native',
      );
      await f.review();
      f.journey.showConfirmation();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriButton>(
              find.widgetWithText(AfriButton, l.nativeMembershipOpenDialer),
            )
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets('retained tab exit clears the phone draft before returning', (
    tester,
  ) async {
    final f = fixture();
    await show(tester, f);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    await tester.enterText(find.byType(TextField), auth.fixturePhone);
    await tester.tap(find.text('Home tab'));
    expect(controller.text, isEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Membership tab'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(f.identity.transport.requests, isEmpty);
  });

  testWidgets('same-object invalidation synchronously clears a code draft', (
    tester,
  ) async {
    final f = fixture();
    await f.journey.requestCode(auth.fixturePhone);
    await show(tester, f);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    await tester.enterText(find.byType(TextField), '654321');
    final before = f.journey.invalidationEpoch;
    f.journey.invalidate();
    expect(f.journey.invalidationEpoch, before + 1);
    expect(controller.text, isEmpty);
    await tester.pumpAndSettle();
    expect(find.text(l.nativeMembershipPhone), findsOneWidget);
  });

  testWidgets(
    'explicit sign out clears retained phone draft while server revocation is pending',
    (tester) async {
      final f = fixture();
      await show(tester, f);
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      await tester.enterText(find.byType(TextField), auth.fixturePhone);
      // Login through the same instance to retain the local draft under the ready view.
      await f.login();
      await tester.pumpAndSettle();
      final reply = Completer<NativeIdentityResponse>();
      f.identity.transport.handler = (_) => reply.future;
      final journals = Map<String, String>.from(f.channel.values);
      final target = find.widgetWithText(AfriButton, l.nativeMembershipSignOut);
      await tester.ensureVisible(target);
      await tester.tap(target);
      expect(controller.text, isEmpty);
      expect(f.journey.busy, isTrue);
      expect(f.channel.values, journals);
      reply.complete(
        auth.jsonResponse({
          'schemaVersion': 1,
          'scope': 'current',
          'revoked': true,
        }),
      );
      await tester.pumpAndSettle();
      expect(f.journey.stage, NativeMembershipStage.signedOut);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(f.dialer.opens, 0);
    },
  );
}
