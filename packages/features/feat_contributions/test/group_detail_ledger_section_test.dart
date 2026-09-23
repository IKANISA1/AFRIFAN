import 'package:core_utils/core_utils.dart';
import 'package:feat_contributions/src/controllers/group_detail_controller.dart';
import 'package:feat_contributions/src/screens/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject(List<GroupLedgerEntry> ledger) {
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

  testWidgets('ledger section renders an explicit empty state', (tester) async {
    await tester.pumpWidget(buildSubject(const <GroupLedgerEntry>[]));

    expect(find.byKey(const ValueKey<String>('group-ledger-empty')), findsOne);
    expect(find.text('Public ledger'), findsOneWidget);
    expect(find.text('No contributions yet'), findsOneWidget);
  });

  testWidgets('ledger section renders contribution rows when entries exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(<GroupLedgerEntry>[
        GroupLedgerEntry(
          publicAlias: '#PENDING',
          amount: 9000,
          status: GroupLedgerStatus.processing,
          createdAt: DateTime.utc(2026, 7, 1),
        ),
        GroupLedgerEntry(
          publicAlias: '#123456',
          amount: 1500,
          status: GroupLedgerStatus.confirmed,
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      ]),
    );

    expect(
      find.byKey(const ValueKey<String>('group-ledger-empty')),
      findsNothing,
    );
    expect(find.text('Public ledger'), findsOneWidget);
    expect(find.text('#123456'), findsOneWidget);
    expect(find.text('#PENDING'), findsNothing);
    expect(find.textContaining('Confirmed'), findsNothing);
    expect(find.textContaining('Processing'), findsNothing);
  });
}
