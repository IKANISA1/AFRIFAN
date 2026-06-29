import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:feat_membership/src/screens/fan_registry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FanRegistryResultsSliver', () {
    testWidgets('hides visible empty registry copy when fans are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _RegistryHarness(
          sliver: FanRegistryResultsSliver(
            isLoading: false,
            error: null,
            fans: const [],
            isLoadingMore: false,
            onRetry: () {},
          ),
        ),
      );

      expect(find.textContaining('No registered fans'), findsNothing);
      expect(find.textContaining('No fan matches'), findsNothing);
      expect(find.textContaining('Once supporters'), findsNothing);
    });

    testWidgets('renders fan cards when fans are available', (tester) async {
      await tester.pumpWidget(
        _RegistryHarness(
          sliver: FanRegistryResultsSliver(
            isLoading: false,
            error: null,
            fans: [
              FanMembership(
                id: 'fan-1',
                userId: 'user-1',
                partnerId: 'rayon',
                displayName: 'Supporter 1024',
                tier: FanTier.gold,
                points: 2400,
                chapter: 'Kigali',
                membershipNumber: 'RS-1024',
                joinedAt: DateTime.utc(2026, 6, 1),
                paymentStatus: PaymentStatus.verified,
              ),
            ],
            isLoadingMore: false,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('SUPPORTER 1024'), findsOneWidget);
      expect(find.text('2400 activity'), findsOneWidget);
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.textContaining('No registered fans'), findsNothing);
    });
  });
}

class _RegistryHarness extends StatelessWidget {
  const _RegistryHarness({required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: CustomScrollView(slivers: [sliver])),
    );
  }
}
