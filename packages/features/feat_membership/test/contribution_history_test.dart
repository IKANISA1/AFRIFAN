import 'package:feat_membership/src/widgets/contribution_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContributionHistorySection', () {
    testWidgets('hides section when contributions are empty', (tester) async {
      await tester.pumpWidget(
        const _HistoryHarness(
          child: ContributionHistorySection(contributions: []),
        ),
      );

      expect(find.text('Contribution history'), findsNothing);
      expect(find.textContaining('No contributions'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders contribution rows when contributions are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _HistoryHarness(
          child: ContributionHistorySection(
            currencySymbol: 'RWF',
            contributions: [
              ContributionRecord(
                date: '28 Jun 2026',
                amount: 25000,
                label: 'Membership',
                status: 'verified',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Contribution history'), findsOneWidget);
      expect(find.text('25000 RWF'), findsOneWidget);
      expect(find.text('Membership'), findsOneWidget);
      expect(find.text('verified'), findsOneWidget);
      expect(find.textContaining('No contributions'), findsNothing);
    });
  });
}

class _HistoryHarness extends StatelessWidget {
  const _HistoryHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: child));
  }
}
