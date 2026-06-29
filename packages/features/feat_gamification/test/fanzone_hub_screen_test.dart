import 'dart:async';

import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/providers/fanzone_hub_provider.dart';
import 'package:feat_gamification/src/screens/fanzone_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_support/design_font_loader.dart';

class _TestFanzoneHubNotifier extends FanzoneHubNotifier {
  _TestFanzoneHubNotifier(this._snapshot);

  final FanzoneHubSnapshot _snapshot;

  @override
  Future<FanzoneHubSnapshot> build() async => _snapshot;

  @override
  Future<void> refresh() async {
    state = AsyncData(_snapshot);
  }
}

class _PendingFanzoneHubNotifier extends FanzoneHubNotifier {
  @override
  Future<FanzoneHubSnapshot> build() => Completer<FanzoneHubSnapshot>().future;
}

FanzoneHubSnapshot _buildSnapshot() {
  return FanzoneHubSnapshot(
    dashboard: const PredictionDashboard(
      totalPredictions: 12,
      settledCount: 8,
      wonCount: 5,
      lostCount: 3,
      activeCount: 4,
      totalFetEarned: 240,
      currentStreak: 3,
      winRate: 62.5,
    ),
    wallet: const FetWalletSummary(
      userId: 'supporter-1',
      clubId: 24,
      membershipId: 'membership-1',
      balance: 1250,
      tier: 'gold',
      weeklyEarned: 200,
      monthlyEarned: 480,
      lifetimeEarned: 1600,
      lifetimeSpent: 350,
      transactionCount: 3,
      legacyBalanceGap: 0,
    ),
    liveFixtures: <FixtureSummary>[
      FixtureSummary(
        id: 'fixture-live',
        competitionSlug: 'rpl',
        competitionName: 'Rwanda Premier League',
        seasonLabel: '2025/26',
        matchday: 24,
        homeTeamName: 'Rayon Sports',
        homeTeamShort: 'RAY',
        awayTeamName: 'Rayon Sports',
        awayTeamShort: 'Rayon Sports',
        kickoffAt: DateTime.utc(2026, 4, 14, 16),
        venueName: 'Kigali Pele Stadium',
        status: 'live',
        homeScore: 2,
        awayScore: 1,
      ),
    ],
    todayFixtures: <FixtureSummary>[
      FixtureSummary(
        id: 'fixture-today',
        competitionSlug: 'rpl',
        competitionName: 'Rwanda Premier League',
        seasonLabel: '2025/26',
        matchday: 25,
        homeTeamName: 'Musanze FC',
        homeTeamShort: 'MUS',
        awayTeamName: 'Etincelles',
        awayTeamShort: 'ETI',
        kickoffAt: DateTime.utc(2026, 4, 14, 19),
        venueName: 'Musanze Stadium',
        status: 'scheduled',
      ),
    ],
    upcomingFixtures: <FixtureSummary>[
      FixtureSummary(
        id: 'fixture-upcoming',
        competitionSlug: 'epl',
        competitionName: 'Premier League',
        seasonLabel: '2025/26',
        matchday: 31,
        homeTeamName: 'Liverpool',
        homeTeamShort: 'LIV',
        awayTeamName: 'Arsenal',
        awayTeamShort: 'ARS',
        kickoffAt: DateTime.utc(2026, 4, 15, 18),
        venueName: 'Anfield',
        status: 'scheduled',
      ),
    ],
    leaderboard: const <PredictionLeaderboardEntry>[
      PredictionLeaderboardEntry(
        rank: 1,
        userId: 'user-1',
        displayName: 'Supporter One',
        wins: 12,
        totalSettled: 18,
        totalFetEarned: 640,
        winRate: 66.7,
      ),
    ],
    markets: const <PredictionMarket>[
      PredictionMarket(
        id: 'market-1',
        slug: '1x2',
        name: 'Match Result',
        shortName: '1X2',
        marketGroup: MarketGroup.matchResult,
        marketCategory: 'Match Betting',
        betType: 'single',
        difficultyTier: DifficultyTier.entry,
        defaultFetValue: 100,
        baseFet: 100,
        description: 'Predict the winner.',
        outcomeTemplate: <MarketOutcomeOption>[
          MarketOutcomeOption(key: 'home', label: 'Home'),
          MarketOutcomeOption(key: 'draw', label: 'Draw'),
          MarketOutcomeOption(key: 'away', label: 'Away'),
        ],
        sortOrder: 1,
        leagueAvailability: <String>['rpl', 'epl'],
      ),
    ],
    challenges: const <FetCatalogItem>[
      FetCatalogItem(
        id: 'cat-1',
        clubId: 24,
        code: 'PREDICTION_WIN',
        templateScope: 'club',
        category: 'Prediction',
        itemName: 'Correct 1X2 Prediction',
        fetValue: 10,
        triggerCondition: 'Win a 1X2 market',
        activationTiming: 'Always on',
        description: 'Base earn for a correct prediction.',
        badgeName: null,
        implementationNotes: null,
        sortOrder: 1,
        isActive: true,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  testWidgets('renders live FANZONE sections from repository data', (
    tester,
  ) async {
    final snapshot = _buildSnapshot();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fanzoneHubProvider.overrideWith(
            () => _TestFanzoneHubNotifier(snapshot),
          ),
        ],
        child: const MaterialApp(home: FanzoneHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fanzone'), findsOneWidget);
    expect(find.text('Fixtures'), findsAtLeastNWidgets(1));
    expect(find.text('Wallet'), findsAtLeastNWidgets(1));
  });

  testWidgets('loading state still exposes fanzone route shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fanzoneHubProvider.overrideWith(() => _PendingFanzoneHubNotifier()),
        ],
        child: const MaterialApp(home: FanzoneHubScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Opening Fanzone'), findsOneWidget);
    expect(find.text('Fixtures'), findsOneWidget);
    expect(find.text('Wallet'), findsAtLeastNWidgets(1));
  });

  testWidgets('offline snapshot shows bounded degraded sections', (
    tester,
  ) async {
    const snapshot = FanzoneHubSnapshot(
      status: FanzoneHubStatus.error,
      message: 'Fanzone is temporarily unavailable.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fanzoneHubProvider.overrideWith(
            () => _TestFanzoneHubNotifier(snapshot),
          ),
        ],
        child: const MaterialApp(home: FanzoneHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live updates paused'), findsOneWidget);
    expect(find.text('Fixtures'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Markets unavailable'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard unavailable'), findsOneWidget);
    expect(find.text('Challenges unavailable'), findsOneWidget);
  });
}
