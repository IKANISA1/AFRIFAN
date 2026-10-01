import 'dart:io';

import 'package:app_registry/app_registry.dart';
import 'package:core_app/bootstrap.dart';
import 'package:core_app/core_app.dart';
import 'package:core_router/core_router.dart';
import 'package:feat_membership/feat_membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/core_app/test/app_deep_link_test.dart'
    show FakeAuthRepository;
import '../../features/feat_membership/test/native_supporter_journey_fixture.dart';
import '../../testing/test_support/test/fixtures/five_club_configs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configs = fiveClubFixtures(Directory('../..').absolute);
  const applications = {
    '6': 'cd.ikanisa.as_vita',
    '24': 'rw.gikundiro.app',
    '26': 'zm.ikanisa.nkana',
    '44': 'bi.ikanisa.vitalo',
    '1001': 'mz.ikanisa.costadosol',
  };
  for (final entry in configs.entries) {
    test(
      'entrypoint wires matching module and provider for ${entry.key}',
      () async {
        final f = JourneyFixture();
        final config = entry.value;
        final journey = NativeSupporterJourney(
          identityClient: NativeIdentityWireClient(
            scope: NativeIdentityScope(
              applicationId: applications[config.clubId]!,
              approvedOrigin: Uri.parse('https://synthetic.invalid'),
              clubId: int.parse(config.clubId),
            ),
            transport: f.identity.transport,
            enabled: true,
          ),
          credentialStore: f.identity.store,
          identityEntropy: f.identity.entropy,
          membershipTransport: f.transport,
          recoveryChannel: f.channel,
          dialer: f.dialer,
          plans: [NativeMembershipPlan('gold', 'Synthetic gold')],
          enabled: true,
        );
        addTearDown(journey.dispose);
        addTearDown(f.journey.dispose);
        const startup = AppStartupOptions(initializeBackend: false);
        final options = clubBootstrapOptions(
          config,
          nativeSupporterJourney: journey,
          startupOptions: startup,
        );
        final selected = options.moduleBuilder!(null)
            .whereType<MembershipModule>()
            .single;
        expect(selected.nativeMembershipSelected, isTrue);
        expect(options.startupOptions, same(startup));
        final container = ProviderContainer(
          overrides: options.providerOverrides,
        );
        expect(container.read(nativeSupporterJourneyProvider), same(journey));
        expect(f.identity.transport.requests, isEmpty);
        expect(f.transport.requests, isEmpty);
        expect(f.identity.store.reads, 0);
        expect(f.dialer.opens, 0);
        container.dispose();
        await journey.requestCode('+250700000001');
        expect(f.identity.transport.requests, isEmpty);
        expect(f.transport.requests, isEmpty);
      },
    );
    test('default ${entry.key} entrypoint grants no native capability', () {
      final options = clubBootstrapOptions(entry.value);
      expect(options.providerOverrides, isEmpty);
      final module = options.moduleBuilder!(null)
          .whereType<MembershipModule>()
          .single;
      expect(module.nativeMembershipSelected, isFalse);
      expect(options.eagerProviders, isEmpty);
    });
    testWidgets('unvisited home scope owns and disposes ${entry.key} journey', (
      tester,
    ) async {
      final f = JourneyFixture();
      final config = entry.value;
      final journey = NativeSupporterJourney(
        identityClient: NativeIdentityWireClient(
          scope: NativeIdentityScope(
            applicationId: applications[config.clubId]!,
            approvedOrigin: Uri.parse('https://synthetic.invalid'),
            clubId: int.parse(config.clubId),
          ),
          transport: f.identity.transport,
          enabled: true,
        ),
        credentialStore: f.identity.store,
        identityEntropy: f.identity.entropy,
        membershipTransport: f.transport,
        recoveryChannel: f.channel,
        dialer: f.dialer,
        plans: [NativeMembershipPlan('gold', 'Synthetic gold')],
        enabled: true,
      );
      addTearDown(journey.dispose);
      addTearDown(f.journey.dispose);
      final options = clubBootstrapOptions(
        config,
        nativeSupporterJourney: journey,
      );
      await tester.pumpWidget(
        AfriClubApp(
          config: config,
          modules: [_UnvisitedHomeModule()],
          authRepository: FakeAuthRepository(),
          initialLocation: '/home',
          providerOverrides: options.providerOverrides,
          eagerProviders: options.eagerProviders,
        ),
      );
      await tester.pump();
      // No test/screen reads the native provider. The app must mount its owner.
      expect(f.identity.transport.requests, isEmpty);
      expect(f.transport.requests, isEmpty);
      expect(f.identity.store.reads, 0);
      expect(f.dialer.opens, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await journey.requestCode('+250700000001');
      expect(f.identity.transport.requests, isEmpty);
      expect(f.transport.requests, isEmpty);
      expect(f.identity.store.reads, 0);
      expect(f.dialer.opens, 0);
    });
  }
  test('foreign journey is rejected before startup or side effects', () {
    final f = JourneyFixture();
    addTearDown(f.journey.dispose);
    expect(
      () => clubBootstrapOptions(
        configs['as_vita']!,
        nativeSupporterJourney: f.journey,
      ),
      throwsArgumentError,
    );
    expect(f.identity.transport.requests, isEmpty);
    expect(f.transport.requests, isEmpty);
  });
}

class _UnvisitedHomeModule extends FeatureModule {
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
    builder: (context, state) =>
        const Scaffold(body: Text('Synthetic public home')),
  );
}
