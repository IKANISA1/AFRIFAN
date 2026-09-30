import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/native_supporter_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/core_auth/test/native_identity/support.dart' as auth;
import 'native_supporter_journey_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    ColorTokens.init();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() => TypographyTokens.debugUseFallbackFonts = false);

  Future<void> show(
    WidgetTester tester,
    NativeSupporterJourney? journey, {
    String club = '24',
    Brightness brightness = Brightness.dark,
    double scale = 1,
    bool keyboard = false,
  }) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: keyboard ? 350 : 0),
            ),
            child: child!,
          ),
          home: NativeMembershipJourneyScreen(
            configuredClubId: club,
            journey: journey,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final l = lookupAfriLocalizations(const Locale('en'));
  JourneyFixture fixture() {
    final f = JourneyFixture();
    addTearDown(f.journey.dispose);
    return f;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(AfriButton, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('absent runtime renders unavailable without any remote work', (
    tester,
  ) async {
    await show(tester, null);
    expect(find.text(l.nativeMembershipUnavailable), findsOneWidget);
    expect(find.byType(AfriButton), findsNothing);
  });
  test(
    'the default platform factory is disabled and performs no channel/network work',
    () async {
      const channel = MethodChannel('africlub/native-identity-credentials/v1');
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            calls++;
            throw StateError('unexpected platform call');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final journey = await openNativeSupporterJourney(
        scope: auth.fixtureScope(),
        plans: [NativeMembershipPlan('gold', 'Synthetic gold')],
      );
      addTearDown(journey.dispose);
      expect(journey.enabled, isFalse);
      expect(journey.stage, NativeMembershipStage.unavailable);
      expect(calls, 0);
    },
  );
  testWidgets('fresh code requires acknowledgement after expired recovery', (
    tester,
  ) async {
    final f = fixture();
    f.identity.transport.handler = (_) =>
        throw StateError('synthetic transport loss');
    await f.journey.requestCode(auth.fixturePhone);
    f.identity.now += 60000;
    await f.journey.recoverIdentity();
    await show(tester, f.journey);
    final restart = find.widgetWithText(AfriButton, l.nativeMembershipRestart);
    expect(tester.widget<AfriButton>(restart).enabled, isFalse);
    final calls = f.identity.transport.requests.length;
    final acknowledgement = find.byType(AfriCheckbox);
    await tester.ensureVisible(acknowledgement);
    await tester.tap(acknowledgement);
    await tester.pumpAndSettle();
    expect(tester.widget<AfriButton>(restart).enabled, isTrue);
    await tap(tester, l.nativeMembershipRestart);
    expect(f.identity.transport.requests.length, calls);
    expect(f.journey.stage, NativeMembershipStage.signedOut);
    expect(find.text(l.nativeMembershipPhone), findsOneWidget);
  });
  testWidgets(
    'wrong club renders unavailable before identity or membership calls',
    (tester) async {
      final f = fixture();
      await show(tester, f.journey, club: '25');
      expect(find.text(l.nativeMembershipUnavailable), findsOneWidget);
      expect(f.identity.transport.requests, isEmpty);
      expect(f.transport.requests, isEmpty);
    },
  );
  testWidgets(
    'saved sign-in reaches review and separately acknowledged confirmation',
    (tester) async {
      final f = fixture();
      await f.login();
      await f.journey.prepare('gold');
      await show(tester, f.journey);
      await tap(tester, l.nativeMembershipReview);
      expect(find.text('10000'), findsOneWidget);
      expect(find.text('RWF'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      expect(f.dialer.opens, 0);
      await tap(tester, l.nativeMembershipContinue);
      final button = tester.widget<AfriButton>(
        find.widgetWithText(AfriButton, l.nativeMembershipOpenDialer),
      );
      expect(button.enabled, isFalse);
      expect(f.dialer.opens, 0);
      final checkbox = find.byType(AfriCheckbox);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AfriButton>(
              find.widgetWithText(AfriButton, l.nativeMembershipOpenDialer),
            )
            .enabled,
        isTrue,
      );
      await tap(tester, l.nativeMembershipOpenDialer);
      expect(f.dialer.opens, 1);
      expect(find.text(l.nativeMembershipUnresolved), findsOneWidget);
      expect(find.text(l.nativeMembershipAllocationRecorded), findsNothing);
    },
  );
  testWidgets(
    'cancel removes acknowledgement and requires a fresh server review',
    (tester) async {
      final f = fixture();
      await f.review();
      await show(tester, f.journey);
      await tap(tester, l.nativeMembershipContinue);
      await tester.ensureVisible(find.byType(AfriCheckbox));
      await tester.tap(find.byType(AfriCheckbox));
      await tester.pumpAndSettle();
      await tap(tester, l.nativeMembershipCancel);
      expect(f.journey.paymentReview, isNull);
      expect(f.dialer.opens, 0);
      await tap(tester, l.nativeMembershipReview);
      await tap(tester, l.nativeMembershipContinue);
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
  testWidgets(
    'recovery status button is read-only and cannot reopen a claimed handoff',
    (tester) async {
      final f = fixture();
      await f.review();
      f.journey.showConfirmation();
      await f.journey.confirmPayment(acknowledgement: true);
      final posts = f.transport.posts;
      await show(tester, f.journey);
      await tap(tester, l.nativeMembershipCheckStatus);
      expect(f.transport.posts, posts);
      expect(f.dialer.opens, 1);
      expect(find.text(l.nativeMembershipOpenDialer), findsNothing);
      expect(find.text(l.nativeMembershipRelease), findsNothing);
    },
  );
  testWidgets(
    'allocated state and historical receipt do not claim current entitlement',
    (tester) async {
      final f = fixture();
      await f.login();
      await f.journey.prepare('gold');
      f.transport.status = 'status:allocated-valid';
      await f.journey.inspectRecovery();
      await show(tester, f.journey);
      await tap(tester, l.nativeMembershipReceipt);
      expect(find.text(l.nativeMembershipReceiptNotice), findsOneWidget);
      expect(find.text(l.nativeMembershipOpenDialer), findsNothing);
      expect(f.dialer.opens, 0);
    },
  );
  testWidgets(
    'route disposal hides private views while retaining recovery markers',
    (tester) async {
      final f = fixture();
      await f.review();
      await show(tester, f.journey);
      final saved = Map<String, String>.from(f.channel.values);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(f.journey.identity, isNull);
      expect(f.journey.paymentReview, isNull);
      expect(f.channel.values, saved);
      expect(f.dialer.opens, 0);
    },
  );
  testWidgets('club switch invalidates the prior private scope', (
    tester,
  ) async {
    final f = fixture();
    await f.review();
    await show(tester, f.journey);
    await show(tester, f.journey, club: '25');
    expect(find.text(l.nativeMembershipUnavailable), findsOneWidget);
    expect(f.journey.identity, isNull);
    expect(f.journey.paymentReview, isNull);
  });
  testWidgets(
    'phone/code fields have labels and code stays obscured with keyboard open',
    (tester) async {
      final f = fixture();
      await show(tester, f.journey, keyboard: true, scale: 2);
      expect(find.text(l.nativeMembershipPhone), findsOneWidget);
      await tester.enterText(find.byType(TextField), auth.fixturePhone);
      await tap(tester, l.nativeMembershipRequestCode);
      expect(find.text(l.nativeMembershipCode), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('keyboard traversal reaches sign-in actions without submitting', (
    tester,
  ) async {
    final f = fixture();
    await show(tester, f.journey);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(f.identity.transport.requests, isEmpty);
    expect(f.transport.requests, isEmpty);
  });
  for (final brightness in Brightness.values) {
    for (final stage in NativeMembershipStage.values) {
      testWidgets(
        '${brightness.name}/${stage.name}: 200% text, reduced motion, labels and touch targets',
        (tester) async {
          final f = JourneyFixture(
            enabled: stage != NativeMembershipStage.unavailable,
          );
          addTearDown(f.journey.dispose);
          switch (stage) {
            case NativeMembershipStage.unavailable:
            case NativeMembershipStage.signedOut:
              break;
            case NativeMembershipStage.codeRequested:
              await f.journey.requestCode(auth.fixturePhone);
            case NativeMembershipStage.ready:
              await f.login();
            case NativeMembershipStage.prepared:
              await f.login();
              await f.journey.prepare('gold');
            case NativeMembershipStage.review:
              await f.review();
            case NativeMembershipStage.confirmation:
              await f.review();
              f.journey.showConfirmation();
            case NativeMembershipStage.unresolved:
              await f.login();
              f.transport.losePrepareAck = true;
              await f.journey.prepare('gold');
              await f.journey.inspectRecovery();
            case NativeMembershipStage.allocationRecorded:
              await f.login();
              await f.journey.prepare('gold');
              f.transport.status = 'status:allocated-valid';
              await f.journey.inspectRecovery();
          }
          expect(f.journey.stage, stage);
          final semantics = tester.ensureSemantics();
          try {
            await show(tester, f.journey, brightness: brightness, scale: 2);
            expect(tester.takeException(), isNull);
            for (final button in find.byType(AfriButton).evaluate()) {
              await tester.ensureVisible(find.byWidget(button.widget));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }
            expect(f.dialer.opens, 0);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
