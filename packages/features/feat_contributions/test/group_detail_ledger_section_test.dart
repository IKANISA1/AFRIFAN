import 'package:core_utils/core_utils.dart';
import 'package:feat_contributions/src/screens/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject(List<Map<String, dynamic>> ledger) {
    return MaterialApp(
      home: Scaffold(
        body: GroupLedgerSection(
          ledger: ledger,
          currencyFormatter: CurrencyFormatter(
            currencyCode: 'RWF',
            currencySymbol: 'RWF',
          ),
        ),
      ),
    );
  }

  testWidgets('ledger section renders nothing when there are no entries', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const <Map<String, dynamic>>[]));

    expect(find.byKey(const ValueKey<String>('group-ledger-empty')), findsOne);
    expect(find.text('LEDGER'), findsNothing);
    expect(
      find.text('No contributions have been recorded for this initiative yet.'),
      findsNothing,
    );
  });

  testWidgets('ledger section renders contribution rows when entries exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(const <Map<String, dynamic>>[
        <String, dynamic>{
          'alias': '#123456',
          'amount': 1500,
          'time': '2h ago',
          'status': 'confirmed',
        },
      ]),
    );

    expect(
      find.byKey(const ValueKey<String>('group-ledger-empty')),
      findsNothing,
    );
    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.text('#123456'), findsOneWidget);
    expect(find.textContaining('CONFIRMED'), findsOneWidget);
  });
}
