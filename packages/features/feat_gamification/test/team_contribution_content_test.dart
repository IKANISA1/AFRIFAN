import 'package:core_utils/core_utils.dart';
import 'package:feat_gamification/src/models/fanzone_models.dart';
import 'package:feat_gamification/src/widgets/team_profile_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/app_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() {
    AfriCountryCatalog.setPreferredCountryCode('RW');
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
  });
  tearDown(() {
    AfriCountryCatalog.setPreferredCountryCode(null);
    AfriCountryCatalog.withCountries(const <AfriCountry>[]);
  });

  Widget buildSubject(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('overview hides contribution route when route is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const TeamOverviewTab(
          team: _team,
          tableRow: null,
          paymentRoute: null,
          isActiveClubTeam: true,
          clubSupportMessage: 'Contribution route unavailable.',
          allowsUnreconciledExternalPaymentLaunch: true,
        ),
      ),
    );

    expect(find.text('MOMO CONTRIBUTION ROUTE'), findsNothing);
    expect(find.text('Contribution route not configured'), findsNothing);
    expect(find.text('Contribution route unavailable.'), findsNothing);
  });

  testWidgets('overview renders contribution route when route exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const TeamOverviewTab(
          team: _team,
          tableRow: null,
          paymentRoute: _route,
          isActiveClubTeam: true,
          clubSupportMessage: null,
          allowsUnreconciledExternalPaymentLaunch: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MOMO CONTRIBUTION ROUTE'), findsOneWidget);
    expect(find.text('MTN MoMo code 1828'), findsOneWidget);
    expect(find.text('Rayon contribution reference'), findsOneWidget);
  });

  testWidgets('contribute tab hides unavailable and missing route states', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        const TeamContributeTab(
          isDialing: false,
          onDial: _noop,
          paymentRoute: null,
          isActiveClubTeam: false,
          clubSupportMessage: 'Contribution route unavailable.',
          allowsUnreconciledExternalPaymentLaunch: true,
        ),
      ),
    );

    expect(find.text('Contributions unavailable'), findsNothing);
    expect(find.text('No contribution route'), findsNothing);
    expect(find.text('Contribution route unavailable.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('team-contribute-empty')),
      findsOne,
    );
  });

  testWidgets('contribute tab renders route instructions when route exists', (
    tester,
  ) async {
    var dialed = false;

    await tester.pumpWidget(
      buildSubject(
        TeamContributeTab(
          isDialing: false,
          onDial: () {
            dialed = true;
          },
          paymentRoute: _route,
          isActiveClubTeam: true,
          clubSupportMessage: null,
          allowsUnreconciledExternalPaymentLaunch: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('team-contribute-empty')),
      findsNothing,
    );
    expect(find.text('MOMO CONTRIBUTION'), findsOneWidget);
    expect(find.text('MTN MoMo code 1828'), findsOneWidget);
    expect(find.text('Rayon contribution reference'), findsOneWidget);

    await tester.tap(find.text('Enter amount & dial'));
    await tester.pump();

    expect(dialed, isTrue);
  });

  testWidgets('store policy hides every external contribution promotion', (
    tester,
  ) async {
    var dialed = false;

    await tester.pumpWidget(
      buildSubject(
        Column(
          children: [
            const Expanded(
              child: TeamOverviewTab(
                team: _team,
                tableRow: null,
                paymentRoute: _route,
                isActiveClubTeam: true,
                clubSupportMessage: null,
                allowsUnreconciledExternalPaymentLaunch: false,
              ),
            ),
            Expanded(
              child: TeamContributeTab(
                isDialing: false,
                onDial: () {
                  dialed = true;
                },
                paymentRoute: _route,
                isActiveClubTeam: true,
                clubSupportMessage: null,
                allowsUnreconciledExternalPaymentLaunch: false,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MOMO CONTRIBUTION ROUTE'), findsNothing);
    expect(find.text('MOMO CONTRIBUTION'), findsNothing);
    expect(find.text('MTN MoMo code 1828'), findsNothing);
    expect(find.text('Rayon contribution reference'), findsNothing);
    expect(find.text('Enter amount & dial'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('team-contribute-empty')),
      findsOne,
    );
    expect(dialed, isFalse);
  });
}

void _noop() {}

const _team = TeamCatalogEntry(
  id: 'team-1',
  slug: 'rayon-sports',
  name: 'Rayon Sports',
  shortName: 'RAY',
  teamType: 'club',
  countryCode: 'RW',
  countryName: 'Rwanda',
  city: 'Kigali',
  foundedYear: 1968,
  crestUrl: null,
  sourceClubSlug: 'rayon-sports',
  sourceClubName: 'Rayon Sports',
  isActive: true,
);

const _route = PartnerPaymentRoute(
  id: 'route-1',
  partnerId: 'club-1',
  partnerName: 'Rayon Sports',
  partnerSlug: 'rayon-sports',
  countryCode: 'RW',
  providerId: 'mtn',
  recipientCode: '1828',
  reconciliationLabel: 'Rayon contribution reference',
  status: PartnerPaymentRouteStatus.active,
);

const _rwanda = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: '',
  currencyCode: 'RWF',
  currencyName: 'Rwandan Franc',
  momoUssdTemplate: '*182*1*1*{recipient}*{amount}#',
  momoCodeUssdTemplate: '*182*8*1*{code}*{amount}#',
);
