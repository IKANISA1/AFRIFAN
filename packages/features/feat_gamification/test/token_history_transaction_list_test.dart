import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/screens/token_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  Widget buildSubject(List<FetWalletTransaction> transactions) {
    return MaterialApp(
      home: Scaffold(
        body: TokenHistoryTransactionList(transactions: transactions),
      ),
    );
  }

  testWidgets('returns SizedBox.shrink when transaction list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const <FetWalletTransaction>[]));

    expect(find.text('No token events yet'), findsNothing);
    expect(find.textContaining('Earn or spend FET'), findsNothing);
    expect(find.byKey(const ValueKey<String>('token-history-empty')), findsOne);
  });

  testWidgets('renders transaction cards with semantic summaries', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      const transaction = FetWalletTransaction(
        id: 'entry-1',
        entryType: 'transfer_in',
        direction: FetWalletEntryDirection.credit,
        amount: 300,
        balanceAfter: 1250,
        counterpartyUserId: 'supporter-2',
        counterpartyDisplayName: 'Jeanne',
        counterpartyPublicUserId: '483912',
        note: 'Away-day refund',
        referenceType: 'transfer',
        referenceId: 'ref-1',
        createdAt: null,
      );

      await tester.pumpWidget(
        buildSubject(const <FetWalletTransaction>[transaction]),
      );

      expect(find.text('Transfer received'), findsOneWidget);
      expect(find.text('Away-day refund'), findsOneWidget);
      expect(find.text('+300 FET'), findsOneWidget);
      expect(find.text('Bal 1250'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Credit transaction, Transfer received, Away-day refund, 300 FET, '
          'balance 1250, Unknown time',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}
