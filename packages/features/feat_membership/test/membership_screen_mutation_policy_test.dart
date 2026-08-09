import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/src/providers/membership_mutation_gateway.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:feat_membership/src/screens/membership_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('free fan activation uses only the free membership RPC gateway', (
    tester,
  ) async {
    final gateway = _RecordingMembershipGateway();
    await _pumpMembership(
      tester,
      gateway: gateway,
      package: const <String, dynamic>{
        'id': 'official-fan',
        'tier': 'fan',
        'title': 'Fan',
        'annual_price': 0,
        'benefits': <String>[],
      },
    );

    await _activate(tester, 'fan');

    expect(gateway.freeActivationCalls, 1);
    expect(gateway.physicalApplications, isEmpty);
  });

  testWidgets('digital offer cannot enter the external payment flow', (
    tester,
  ) async {
    final gateway = _RecordingMembershipGateway();
    await _pumpMembership(
      tester,
      gateway: gateway,
      package: const <String, dynamic>{
        'id': 'remote-digital',
        'tier': 'gold',
        'title': 'Digital Gold',
        'annual_price': 1000,
        'benefits': <String>['In-app entitlement'],
        'benefit_scope': 'digital_entitlement',
        'store_billing_required': true,
      },
    );

    await _activate(tester, 'gold');

    expect(gateway.freeActivationCalls, 0);
    expect(gateway.physicalApplications, isEmpty);
  });
}

Future<void> _pumpMembership(
  WidgetTester tester, {
  required _RecordingMembershipGateway gateway,
  required Map<String, dynamic> package,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final snapshot = MembershipSnapshot(
    packages: <Map<String, dynamic>>[package],
    membership: null,
    applications: const <Map<String, dynamic>>[],
    contributions: const [],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        currentUserProvider.overrideWith(
          (ref) => const UserProfile(
            id: 'user-1',
            clubId: '24',
            publicUserId: '483912',
          ),
        ),
        membershipMutationGatewayProvider.overrideWithValue(gateway),
        membershipProvider.overrideWith(
          () => MembershipNotifier(loadOverride: () async => snapshot),
        ),
      ],
      child: MaterialApp(
        theme: ClubTheme.from(ClubConfig.fallback()),
        home: const MembershipScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _activate(WidgetTester tester, String tier) async {
  final action = find.byKey(ValueKey<String>('membership-action-$tier'));
  await tester.scrollUntilVisible(
    action,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

class _RecordingMembershipGateway implements MembershipMutationGateway {
  int freeActivationCalls = 0;
  final List<({String tier, String reference, String? chapter})>
  physicalApplications = [];

  @override
  Future<Map<String, dynamic>> activateFreeMembership() async {
    freeActivationCalls += 1;
    return <String, dynamic>{'id': 'membership-1', 'tier': 'fan'};
  }

  @override
  Future<Map<String, dynamic>> submitPhysicalApplication({
    required String tier,
    required String paymentReference,
    String? chapter,
  }) async {
    physicalApplications.add((
      tier: tier,
      reference: paymentReference,
      chapter: chapter,
    ));
    return <String, dynamic>{
      'id': 'application-1',
      'metadata': <String, dynamic>{'amount': 1000},
    };
  }
}
