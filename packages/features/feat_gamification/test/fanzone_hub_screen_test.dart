import 'package:feat_gamification/src/fet_providers.dart';
import 'package:feat_gamification/src/models/fanzone_models.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:feat_gamification/src/repositories/fet_repository.dart';
import 'package:feat_gamification/src/repositories/prediction_repository.dart';
import 'package:feat_gamification/src/screens/fanzone_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:test_support/design_font_loader.dart';

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _FakePredictionRepository extends PredictionRepository {
  _FakePredictionRepository() : super(client: _MockSupabaseClient());

  @override
  Future<PredictionDashboard> loadUserStats() async {
    return const PredictionDashboard(
      totalPredictions: 12,
      settledCount: 8,
      wonCount: 5,
      lostCount: 3,
      activeCount: 4,
      totalFetEarned: 240,
      currentStreak: 3,
      winRate: 62.5,
    );
  }

  @override
  Future<List<FixtureSummary>> loadFixtures({
    String? competitionSlug,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    if (status == 'live') {
      return <FixtureSummary>[
        FixtureSummary(
          id: 'fixture-live',
          competitionSlug: 'rpl',
          competitionName: 'Rwanda Premier League',
          seasonLabel: '2025/26',
          matchday: 24,
          homeTeamName: 'Rayon Sports',
          homeTeamShort: 'RAY',
          awayTeamName: 'APR',
          awayTeamShort: 'APR',
          kickoffAt: DateTime.utc(2026, 4, 14, 16),
          venueName: 'Kigali Pele Stadium',
          status: 'live',
          homeScore: 2,
          awayScore: 1,
        ),
      ];
    }

    return <FixtureSummary>[
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
    ];
  }

  @override
  Future<List<FixtureSummary>> loadFixturesByDate({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? competitionSlug,
    String? status,
    int limit = 200,
  }) async {
    return <FixtureSummary>[
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
        kickoffAt: DateTime.now().add(const Duration(hours: 3)),
        venueName: 'Musanze Stadium',
        status: 'scheduled',
      ),
    ];
  }

  @override
  Future<List<FixtureDateSummary>> loadFixtureDateSummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? competitionSlug,
  }) async {
    return const <FixtureDateSummary>[];
  }

  @override
  Future<List<PredictionLeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    String? scope,
    String? period,
  }) async {
    return const <PredictionLeaderboardEntry>[
      PredictionLeaderboardEntry(
        rank: 1,
        userId: 'user-1',
        displayName: 'Supporter One',
        wins: 12,
        totalSettled: 18,
        totalFetEarned: 640,
        winRate: 66.7,
      ),
    ];
  }

  @override
  Future<List<PredictionMarket>> loadMarketCatalog() async {
    return const <PredictionMarket>[
      PredictionMarket(
        id: 'market-1',
        slug: '1x2',
        name: 'Match Result',
        shortName: '1X2',
        marketGroup: MarketGroup.matchResult,
        difficultyTier: DifficultyTier.entry,
        defaultFetValue: 100,
        description: 'Predict the winner.',
        outcomeTemplate: <MarketOutcomeOption>[
          MarketOutcomeOption(key: 'home', label: 'Home'),
          MarketOutcomeOption(key: 'draw', label: 'Draw'),
          MarketOutcomeOption(key: 'away', label: 'Away'),
        ],
        sortOrder: 1,
      ),
    ];
  }
}

class _FakeFetRepository extends FetRepository {
  _FakeFetRepository() : super(client: _MockSupabaseClient());

  @override
  Future<FetWalletSummary?> loadWallet() async {
    return const FetWalletSummary(
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
    );
  }

  @override
  Future<List<FetCatalogItem>> loadCatalog() async {
    return const <FetCatalogItem>[
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
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadDesignFonts);

  testWidgets('renders live FANZONE sections from repository data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(),
          ),
          fetRepositoryProvider.overrideWithValue(_FakeFetRepository()),
        ],
        child: const MaterialApp(home: FanzoneHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FANZONE'), findsOneWidget);
    expect(find.text('Fixtures'), findsAtLeastNWidgets(1));
    expect(find.text('Wallet'), findsAtLeastNWidgets(1));
  });
}
