import 'package:feat_fan_clubs/src/screens/fan_clubs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FanClubsResultsSliver', () {
    testWidgets('explains an empty directory without inventing fan clubs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ResultsHarness(
          sliver: FanClubsResultsSliver(
            isLoading: false,
            error: null,
            visibleClubs: const [],
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('No fan clubs found'), findsOneWidget);
      expect(find.textContaining('No clubs found'), findsNothing);
      expect(find.textContaining('New fan clubs'), findsNothing);
    });

    testWidgets('renders fan club cards when clubs are available', (
      tester,
    ) async {
      final clubs = [
        {
          'id': 'ikipe-yacu-nyarugenge',
          'name': 'Ikipe Yacu Nyarugenge',
          'region': 'Kigali',
          'member_count': 42,
        },
      ];

      await tester.pumpWidget(
        _ResultsHarness(
          sliver: FanClubsResultsSliver(
            isLoading: false,
            error: null,
            visibleClubs: clubs,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Ikipe Yacu Nyarugenge'), findsOneWidget);
      expect(find.text('Kigali • 42 members'), findsOneWidget);
      expect(find.text('View joining options'), findsNothing);
      expect(find.text('Status'), findsNothing);
      expect(find.textContaining('No fan clubs'), findsNothing);
    });
  });
}

class _ResultsHarness extends StatelessWidget {
  const _ResultsHarness({required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: CustomScrollView(slivers: [sliver])),
    );
  }
}
