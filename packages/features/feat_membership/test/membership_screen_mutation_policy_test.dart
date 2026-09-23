import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_membership/src/providers/membership_mutation_gateway.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:feat_membership/src/screens/membership_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    AfriCountryCatalog.withCountries(const [
      AfriCountry(
        isoCode: 'RW',
        dialCode: '+250',
        name: 'Rwanda',
        flagEmoji: '',
        currencyCode: 'RWF',
        currencyName: 'Rwandan franc',
        momoUssdTemplate: '*182*{recipient}*{amount}#',
      ),
    ]);
  });
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('there is no free membership activation', (tester) async {
    final gateway = _RecordingMembershipGateway();
    await _pumpMembership(
      tester,
      gateway: gateway,
      package: const {
        'id': 'free',
        'tier': 'fan',
        'annual_price': 0,
        'benefits': <String>[],
      },
    );
    expect(
      find.byKey(const ValueKey<String>('membership-action-fan')),
      findsNothing,
    );
    expect(gateway.selectedTiers, isEmpty);
  });
  testWidgets(
    'any paid tier opens MoMo with the server price and no application',
    (tester) async {
      final gateway = _RecordingMembershipGateway();
      final launches = <String>[];
      await _pumpMembership(
        tester,
        gateway: gateway,
        package: const {
          'id': 'paid',
          'tier': 'gold',
          'annual_price': 500,
          'benefits': <String>[],
          'benefit_scope': 'unclassified',
        },
        paymentLauncher: (recipient, amount, country) async {
          launches.add('$country/$recipient/$amount');
          return true;
        },
      );
      await _activate(tester, 'gold');
      expect(gateway.selectedTiers, ['gold']);
      expect(launches, ['RW/12345/1000']);
      expect(find.textContaining('application'), findsNothing);
      expect(find.text('Pending verification'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _pumpMembership(
  WidgetTester tester, {
  required _RecordingMembershipGateway gateway,
  required Map<String, dynamic> package,
  Future<bool> Function(String, int, String)? paymentLauncher,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final snapshot = MembershipSnapshot(
    packages: <Map<String, dynamic>>[package],
    membership: null,

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
        home: MembershipScreen(paymentLauncher: paymentLauncher),
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
  final selectedTiers = <String>[];
  @override
  Future<Map<String, dynamic>> preparePayment({
    required String tier,
    required int clubId,
  }) async {
    selectedTiers.add(tier);
    return {
      'id': 'order-1',
      'amount': 1000,
      'recipient_code': '12345',
      'country': 'RW',
    };
  }
}
