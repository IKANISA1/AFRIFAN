import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/native_supporter_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';

import '../../../app_registry/tool/generate_route_inventory.dart';
import '../../../core/core_auth/test/native_identity/support.dart' as auth;
import '../../../features/feat_membership/test/native_supporter_journey_fixture.dart';
import 'fixtures/five_club_configs.dart';
import 'fixtures/local_route_state_assertions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  final workspace = resolveRouteInventoryWorkspace(Directory.current);
  final l = lookupAfriLocalizations(const Locale('en'));
  const states = [
    'loading',
    'empty',
    'error',
    'offline',
    'permission_denied',
    'disabled',
    'focused',
    'pressed',
    'selected',
    'large_text',
    'reduced_motion',
    'dark',
    'light',
    'syncing',
    'conflict',
    'security_timeout',
  ];
  for (final club in fiveClubFixtures(workspace).entries) {
    for (final state in states) {
      testWidgets('five club ${club.key} native membership $state', (
        tester,
      ) async {
        localRouteFixtureConfig = club.value;
        localRouteFixtureClub = club.key;
        TypographyTokens.debugUseFallbackFonts = true;
        addTearDown(() {
          localRouteFixtureConfig = null;
          localRouteFixtureClub = null;
          TypographyTokens.debugUseFallbackFonts = false;
        });
        final id = int.parse(club.value.clubId);
        final f = JourneyFixture(
          enabled: state != 'disabled',
          plans: state == 'empty' ? [] : null,
          scope: auth.fixtureScope(
            clubId: id,
            app: 'com.africlub.${club.key.replaceAll('_', '')}',
            origin: 'https://${club.key.replaceAll('_', '-')}.example.test',
          ),
        );
        addTearDown(f.journey.dispose);
        expect(f.journey.scope.clubId, id);
        expect(f.identity.transport.clubId, id);
        expect(f.transport.clubId, id);
        Future<void>? pending;
        Completer<NativeIdentityResponse>? identityReply;
        final ready = ![
          'loading',
          'error',
          'disabled',
          'focused',
          'pressed',
        ].contains(state);
        if (ready) await f.login();
        if (state == 'error') {
          await f.journey.requestCode('invalid phone');
          expect(f.journey.problem, NativeJourneyProblem.invalidInput);
        } else if (state == 'offline') {
          f.identity.transport.handler = (_) =>
              throw const SocketException('synthetic offline');
          await f.journey.checkSession();
          expect(f.journey.problem, NativeJourneyProblem.retry);
        } else if (state == 'permission_denied' || state == 'conflict') {
          f.transport.forcedResponse = NativeWireResponse(
            state == 'conflict' ? 409 : 403,
            {'content-type': 'application/json', 'cache-control': 'no-store'},
            jsonEncode({
              'schemaVersion': 1,
              'error': state == 'conflict'
                  ? 'session_changed'
                  : 'permission_denied',
            }),
          );
          await f.journey.prepare('gold');
          expect(
            f.journey.problem,
            state == 'conflict'
                ? NativeJourneyProblem.changed
                : NativeJourneyProblem.denied,
          );
        } else if (state == 'selected') {
          await f.journey.prepare('gold');
          await f.journey.reviewPayment();
          f.journey.showConfirmation();
        } else if (state == 'loading') {
          identityReply = Completer<NativeIdentityResponse>();
          f.identity.transport.handler = (_) => identityReply!.future;
          pending = f.journey.requestCode(auth.fixturePhone);
          await tester.pump();
          expect(f.journey.busy, isTrue);
          expect(f.journey.identity, isNull);
        } else if (state == 'syncing') {
          f.transport.prepareSent = Completer<void>();
          f.transport.prepareReply = Completer<NativeWireResponse>();
          pending = f.journey.prepare('gold');
          await f.transport.prepareSent!.future;
          expect(f.journey.busy, isTrue);
          expect(f.journey.checkout, isNull);
        } else if (state == 'security_timeout') {
          identityReply = Completer<NativeIdentityResponse>();
          f.identity.transport.handler = (_) => identityReply!.future;
          pending = f.journey.checkSession();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 101));
          await pending;
          pending = null;
          expect(f.journey.problem, NativeJourneyProblem.retry);
          expect(f.journey.busy, isFalse);
        }
        final brightness = state == 'light'
            ? Brightness.light
            : Brightness.dark;
        ColorTokens.setBrightness(brightness);
        addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ClubTheme.from(club.value, brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(state == 'large_text' ? 2 : 1),
                  disableAnimations: state == 'reduced_motion',
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const ValueKey('native-state-boundary'),
                child: NativeMembershipJourneyScreen(
                  configuredClubId: club.value.clubId,
                  journey: f.journey,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
        TestGesture? held;
        try {
          if (state == 'selected') {
            await tester.ensureVisible(find.byType(AfriCheckbox));
            await tester.tap(find.byType(AfriCheckbox));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              tester.widget<AfriCheckbox>(find.byType(AfriCheckbox)).value,
              true,
            );
          } else if (state == 'focused') {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            expect(FocusManager.instance.primaryFocus, isNotNull);
          } else if (state == 'pressed') {
            final target = find.widgetWithText(
              AfriButton,
              l.nativeMembershipRequestCode,
            );
            held = await tester.startGesture(tester.getCenter(target));
            await tester.pump(const Duration(milliseconds: 120));
          }
          if (state == 'loading' || state == 'syncing') {
            expect(find.byType(AfriLinearProgressIndicator), findsOneWidget);
          }
          if (state == 'empty') {
            expect(find.text(l.nativeMembershipNoPlans), findsOneWidget);
          }
          if (state == 'disabled') {
            expect(find.text(l.nativeMembershipUnavailable), findsOneWidget);
          }
          if (state == 'error') {
            expect(find.text(l.nativeMembershipInvalidInput), findsOneWidget);
          }
          if (state == 'permission_denied') {
            expect(find.text(l.nativeMembershipDenied), findsOneWidget);
          }
          if (state == 'conflict') {
            expect(find.text(l.nativeMembershipChanged), findsOneWidget);
          }
          if (state == 'offline' || state == 'security_timeout') {
            expect(find.text(l.nativeMembershipRetry), findsOneWidget);
          }
          expect(find.textContaining('synthetic offline'), findsNothing);
          expect(f.dialer.opens, 0);
          await expectGoldenOrClubAssertions(
            tester,
            find.byKey(const ValueKey('native-state-boundary')),
            'native_state_${state}_${brightness.name}.png',
            route: '/membership/native',
            kind: 'route',
          );
        } finally {
          await held?.cancel();
          if (identityReply != null && !identityReply.isCompleted) {
            identityReply.complete(
              auth.jsonResponse(
                state == 'loading'
                    ? auth.challengeFixture(clubId: id)
                    : auth.sessionFixture(clubId: id),
                status: state == 'loading' ? 202 : 200,
              ),
            );
          }
          if (f.transport.prepareReply != null &&
              !f.transport.prepareReply!.isCompleted) {
            final response = Map<String, Object?>.from(
              f.transport.vectors['prepared:valid']!,
            )..['requestId'] = f.transport.prepareKeys.single;
            f.transport.prepareReply!.complete(f.transport.reply(response));
          }
          await pending;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });
    }
  }
}
