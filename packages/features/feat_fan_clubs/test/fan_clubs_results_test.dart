import 'package:feat_fan_clubs/src/screens/fan_clubs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FanClubsResultsSliver', () {
    testWidgets('hides empty fan club placeholder copy when clubs are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ResultsHarness(
          sliver: FanClubsResultsSliver(
            isLoading: false,
            error: null,
            visibleClubs: const [],
            joinedClubIds: const {},
            pendingClubIds: const {},
            onRetry: () {},
            onOpenClub: (_) {},
            onJoinToggled: (_) {},
          ),
        ),
      );

      expect(find.textContaining('No fan clubs'), findsNothing);
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
            joinedClubIds: const {},
            pendingClubIds: const {},
            onRetry: () {},
            onOpenClub: (_) {},
            onJoinToggled: (_) {},
          ),
        ),
      );

      expect(find.text('IKIPE YACU NYARUGENGE'), findsOneWidget);
      expect(find.text('KIGALI • 42 MEMBERS'), findsOneWidget);
      expect(find.text('Request review'), findsOneWidget);
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
