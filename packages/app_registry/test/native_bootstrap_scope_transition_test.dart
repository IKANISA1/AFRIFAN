import 'dart:convert';
import 'dart:io';

import 'package:app_registry/app_registry.dart';
import 'package:core_app/core_app.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/feat_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core/core_app/test/app_routing_guard_test.dart'
    show FakeAuthRepository;
import '../../features/feat_membership/test/native_supporter_journey_fixture.dart';
import '../../testing/test_support/test/fixtures/five_club_configs.dart';
import '../tool/generate_route_inventory.dart'
    show resolveRouteInventoryWorkspace;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = fiveClubFixtures(
    resolveRouteInventoryWorkspace(Directory.current),
  )['rayon_sports']!;

  for (final replaceRepository in [false, true]) {
    testWidgets(
      'fresh native bootstrap overrides retain the same supplied journey '
      'on same-club ${replaceRepository ? 'repository replacement' : 'rebuild'}',
      (tester) async {
        ColorTokens.init();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = JourneyFixture();
        final journey = fixture.journey;
        addTearDown(journey.dispose);
        final first = FakeAuthRepository(clubId: config.clubId);
        final second = replaceRepository
            ? FakeAuthRepository(clubId: config.clubId)
            : first;

        // Each invocation constructs the real bootstrap override again. Reusing
        // one override list or substituting an ordinary owner would miss the
        // ProviderScope.updateOverrides behavior under review.
        AfriClubApp app(FakeAuthRepository repository) {
          final options = clubBootstrapOptions(
            config,
            nativeSupporterJourney: journey,
          );
          return AfriClubApp(
            key: const ValueKey('retained-native-bootstrap-root'),
            config: config,
            modules: [_BootstrapPublicHomeModule()],
            authRepository: repository,
            initialLocation: '/home',
            providerOverrides: options.providerOverrides,
            eagerProviders: options.eagerProviders,
            onAccountChanged: options.onAccountChanged,
          );
        }

        await tester.pumpWidget(app(first));
        await tester.pumpAndSettle();
        final context = tester.element(find.text('Synthetic bootstrap home'));
        final container = ProviderScope.containerOf(context);
        final routes = GoRouter.of(context).routeInformationProvider;
        expect(container.read(nativeSupporterJourneyProvider), same(journey));
        expect(fixture.identity.transport.requests, isEmpty);
        expect(fixture.identity.store.reads, 0);

        final beforeUpdate = journey.invalidationEpoch;
        await tester.pumpWidget(app(second));
        await tester.pumpAndSettle();
        final updatedContext = tester.element(
          find.text('Synthetic bootstrap home'),
        );
        expect(ProviderScope.containerOf(updatedContext), same(container));
        expect(
          GoRouter.of(updatedContext).routeInformationProvider,
          same(routes),
        );
        expect(
          tester.widget<AfriClubApp>(find.byType(AfriClubApp)).authRepository,
          same(second),
        );
        expect(container.read(nativeSupporterJourneyProvider), same(journey));
        if (replaceRepository) {
          expect(journey.invalidationEpoch, greaterThan(beforeUpdate));
          expect(journey.stage, NativeMembershipStage.signedOut);
        }

        // A disposed real controller silently ignores both operations. Exercise
        // its actual state transition and the existing memory transport rather
        // than inferring lifetime from the returned provider object alone.
        final beforeInvalidate = journey.invalidationEpoch;
        journey.invalidate();
        expect(journey.invalidationEpoch, beforeInvalidate + 1);
        await journey.requestCode('+10000000001');
        expect(fixture.identity.transport.requests.length, 1);
        expect(journey.stage, NativeMembershipStage.codeRequested);
        expect(fixture.transport.requests, isEmpty);
        expect(fixture.dialer.opens, 0);

        final beforeUnmount = journey.invalidationEpoch;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        final afterUnmount = journey.invalidationEpoch;
        expect(afterUnmount, beforeUnmount + 1);
        journey.invalidate();
        await journey.requestCode('+10000000001');
        expect(journey.invalidationEpoch, afterUnmount);
        expect(fixture.identity.transport.requests.length, 1);
        expect(fixture.transport.requests, isEmpty);
        expect(fixture.dialer.opens, 0);
        // ignore: avoid_print
        print(
          jsonEncode({
            'nativeBootstrapScopeTransition': 1,
            'repositoryReplaced': replaceRepository,
            'sameProviderContainer': true,
            'sameSuppliedJourneyRemainedUsable': true,
            'syntheticIdentityRequestsBeforeUnmount': 1,
            'syntheticIdentityRequestsAfterUnmount': 1,
            'unmountInvalidationCount': afterUnmount - beforeUnmount,
          }),
        );
      },
    );
  }
}

class _BootstrapPublicHomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';
  @override
  bool isEnabled(Map<String, bool> flags) => true;
  @override
  Set<String> get publicPaths => {'/home'};
  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'Home',
    icon: Icons.home,
    builder: (_, __) => const Scaffold(body: Text('Synthetic bootstrap home')),
  );
}
