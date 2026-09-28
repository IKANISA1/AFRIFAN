import 'package:core_l10n/core_l10n.dart';
import 'package:feat_membership/src/widgets/digital_membership_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = <Locale>[Locale('en')];

  for (final locale in locales) {
    testWidgets(
      'digital card consumes ${locale.languageCode} membership copy',
      (tester) async {
        final l10n = lookupAfriLocalizations(locale);

        await tester.pumpWidget(
          _LocalizedHarness(
            locale: locale,
            child: DigitalMembershipCardFull(
              clubName: 'Rayon Sports FC',
              tier: 'Gold',
              fanId: 'FAN-1024',
              memberSince: '2026',
              onShare: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('RAY'), findsOneWidget);
        expect(find.text('Rayon Sports FC'), findsNothing);
        expect(find.byTooltip(l10n.shareMembershipCard), findsOneWidget);
        expect(find.text(l10n.membershipSince('2026')), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.shareMembershipCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _LocalizedHarness extends StatelessWidget {
  const _LocalizedHarness({required this.locale, required this.child});

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AfriLocalizationsScope(
        locale: locale,
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
