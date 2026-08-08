import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:feat_gamification/src/repositories/fet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class FakeChallengeRepository extends ChallengeRepository {
  FakeChallengeRepository() : super(client: MockSupabaseClient());

  List<Challenge> featuredChallenges = const <Challenge>[];
  List<Challenge> openChallenges = const <Challenge>[];
  List<Challenge> settledChallenges = const <Challenge>[];
  List<Challenge> myOpenChallenges = const <Challenge>[];
  List<Challenge> myLockedChallenges = const <Challenge>[];
  List<Challenge> mySettledChallenges = const <Challenge>[];
  List<Challenge> myVoidedChallenges = const <Challenge>[];
  final Map<String, ChallengeDetailPayload?> detailsById =
      <String, ChallengeDetailPayload?>{};

  ChallengeMutationResult createResult = const ChallengeMutationResult(
    status: 'error',
  );
  ChallengeMutationResult joinResult = const ChallengeMutationResult(
    status: 'error',
  );
  ChallengeMutationResult cancelResult = const ChallengeMutationResult(
    status: 'error',
  );

  Map<String, dynamic>? lastCreateRequest;
  Map<String, dynamic>? lastJoinRequest;
  String? lastCancelledChallengeId;
  List<String>? lastMyStatuses;
  String? lastMySort;
  Object? loadError;
  Completer<List<Challenge>>? loadCompleter;
  int loadCalls = 0;
  Object? detailLoadError;
  Completer<ChallengeDetailPayload?>? detailLoadCompleter;
  int detailLoadCalls = 0;
  Object? joinError;
  Completer<ChallengeMutationResult>? joinCompleter;
  int joinCalls = 0;
  Object? cancelError;
  Completer<ChallengeMutationResult>? cancelCompleter;
  int cancelCalls = 0;
  Object? createError;
  Completer<ChallengeMutationResult>? createCompleter;
  int createCalls = 0;

  @override
  Future<List<Challenge>> loadChallenges({
    List<String>? statuses,
    String sort = 'ending_soon',
    int limit = 20,
    int offset = 0,
    bool onlyJoined = false,
  }) async {
    loadCalls++;
    final error = loadError;
    if (error != null) throw error;
    final completer = loadCompleter;
    if (completer != null) return completer.future;
    if (onlyJoined) {
      return myOpenChallenges;
    }
    final normalized = (statuses ?? const <String>[])
        .map((value) => value.toLowerCase())
        .toSet();
    if (sort == 'high_pool' && featuredChallenges.isNotEmpty) {
      return featuredChallenges;
    }
    if (normalized.contains('settled') ||
        normalized.contains('void') ||
        normalized.contains('cancelled')) {
      return settledChallenges;
    }
    return openChallenges;
  }

  @override
  Future<List<Challenge>> loadMyChallenges({
    List<String>? statuses,
    String sort = 'ending_soon',
    int limit = 20,
    int offset = 0,
  }) async {
    loadCalls++;
    final error = loadError;
    if (error != null) throw error;
    final completer = loadCompleter;
    if (completer != null) return completer.future;
    lastMyStatuses = statuses;
    lastMySort = sort;
    final normalized = (statuses ?? const <String>[])
        .map((value) => value.toLowerCase())
        .toSet();
    if (normalized.contains('open') && normalized.contains('locked')) {
      return <Challenge>[...myOpenChallenges, ...myLockedChallenges];
    }
    if (normalized.contains('locked')) {
      return myLockedChallenges;
    }
    if (normalized.contains('settled')) {
      return mySettledChallenges;
    }
    if (normalized.contains('void') || normalized.contains('cancelled')) {
      return myVoidedChallenges;
    }
    return myOpenChallenges;
  }

  @override
  Future<ChallengeDetailPayload?> loadChallengeDetail(
    String challengeId,
  ) async {
    detailLoadCalls++;
    final error = detailLoadError;
    if (error != null) throw error;
    final completer = detailLoadCompleter;
    if (completer != null) return completer.future;
    return detailsById[challengeId];
  }

  @override
  Future<ChallengeMutationResult> createChallenge({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required int stakeFet,
  }) async {
    createCalls++;
    final error = createError;
    if (error != null) throw error;
    final completer = createCompleter;
    if (completer != null) return completer.future;
    lastCreateRequest = <String, dynamic>{
      'matchId': matchId,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'stakeFet': stakeFet,
    };
    return createResult;
  }

  @override
  Future<ChallengeMutationResult> joinChallenge({
    required String challengeId,
    required int homeScore,
    required int awayScore,
  }) async {
    joinCalls++;
    final error = joinError;
    if (error != null) throw error;
    final completer = joinCompleter;
    if (completer != null) return completer.future;
    lastJoinRequest = <String, dynamic>{
      'challengeId': challengeId,
      'homeScore': homeScore,
      'awayScore': awayScore,
    };
    return joinResult;
  }

  @override
  Future<ChallengeMutationResult> cancelChallenge(String challengeId) async {
    cancelCalls++;
    final error = cancelError;
    if (error != null) throw error;
    final completer = cancelCompleter;
    if (completer != null) return completer.future;
    lastCancelledChallengeId = challengeId;
    return cancelResult;
  }
}

class FakeChallengeFixturesGateway extends ChallengeFixturesGateway {
  FakeChallengeFixturesGateway({this.fixtures = const <FixtureSummary>[]})
    : super(PredictionRepository(client: MockSupabaseClient()));

  List<FixtureSummary> fixtures = const <FixtureSummary>[];
  Object? loadError;
  Completer<List<FixtureSummary>>? loadCompleter;
  int loadCalls = 0;

  @override
  Future<List<FixtureSummary>> loadFixtures({
    String? competitionSlug,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    loadCalls++;
    final error = loadError;
    if (error != null) throw error;
    final completer = loadCompleter;
    if (completer != null) return completer.future;
    return fixtures;
  }
}

class FakeFetRepository extends FetRepository {
  FakeFetRepository() : super(client: MockSupabaseClient());

  FetWalletSummary? wallet;

  @override
  Future<FetWalletSummary?> loadWallet() async => wallet;

  @override
  Future<List<FetWalletTransaction>> loadWalletTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    return const <FetWalletTransaction>[];
  }
}

FixtureSummary buildFixture({
  String id = 'fixture-1',
  String homeTeamName = 'Rayon Sports',
  String homeTeamShort = 'RAY',
  String awayTeamName = 'APR FC',
  String awayTeamShort = 'APR',
  DateTime? kickoffAt,
  String competitionName = 'Rwanda Premier League',
  String status = 'scheduled',
  int? homeScore,
  int? awayScore,
}) {
  return FixtureSummary(
    id: id,
    competitionSlug: 'rwanda-premier-league',
    competitionName: competitionName,
    seasonLabel: '2025/26',
    matchday: 29,
    homeTeamName: homeTeamName,
    homeTeamShort: homeTeamShort,
    awayTeamName: awayTeamName,
    awayTeamShort: awayTeamShort,
    kickoffAt: kickoffAt ?? DateTime.utc(2026, 4, 20, 16),
    venueName: 'Amahoro Stadium',
    status: status,
    homeScore: homeScore,
    awayScore: awayScore,
  );
}

ChallengeEntry buildEntry({
  String id = 'entry-1',
  String challengeId = 'challenge-1',
  String userId = 'supporter-1',
  int homeScore = 2,
  int awayScore = 1,
  int stakeFet = 3000,
  ChallengeEntryStatus status = ChallengeEntryStatus.active,
  int payoutFet = 0,
  String userName = 'Jeanne Mukamana',
}) {
  return ChallengeEntry(
    id: id,
    challengeId: challengeId,
    userId: userId,
    predictedHomeScore: homeScore,
    predictedAwayScore: awayScore,
    stakeFet: stakeFet,
    status: status,
    payoutFet: payoutFet,
    joinedAt: DateTime.utc(2026, 4, 17, 10),
    userName: userName,
    user: ChallengeUser(id: userId, displayName: userName),
  );
}

Challenge buildChallenge({
  String id = 'challenge-1',
  FixtureSummary? fixture,
  ChallengeStatus status = ChallengeStatus.open,
  int stakeFet = 3000,
  int totalParticipants = 2,
  int totalPoolFet = 6000,
  ChallengeEntry? myEntry,
  ChallengePermissions permissions = const ChallengePermissions(canJoin: true),
  ChallengeSettlementSummary? settlement,
  String? voidReason,
  DateTime? lockAt,
}) {
  final resolvedFixture = fixture ?? buildFixture();
  return Challenge(
    id: id,
    matchId: resolvedFixture.id,
    creatorUserId: 'creator-1',
    stakeFet: stakeFet,
    status: status,
    lockAt: lockAt ?? DateTime.now().toUtc().add(const Duration(hours: 6)),
    totalParticipants: totalParticipants,
    totalPoolFet: totalPoolFet,
    clubId: 24,
    voidReason: voidReason,
    winnerCount: settlement?.winnersCount ?? 0,
    loserCount: settlement?.losersCount ?? 0,
    payoutPerWinnerFet: settlement?.payoutPerWinnerFet ?? 0,
    officialHomeScore: settlement?.officialHomeScore,
    officialAwayScore: settlement?.officialAwayScore,
    createdAt: DateTime.utc(2026, 4, 17, 9),
    updatedAt: DateTime.utc(2026, 4, 17, 9),
    creatorName: 'Alice Uwera',
    fixture: resolvedFixture,
    creator: const ChallengeUser(id: 'creator-1', displayName: 'Alice Uwera'),
    creatorPrediction: const ChallengeScorePrediction(
      homeScore: 2,
      awayScore: 1,
    ),
    myEntry: myEntry,
    permissions: permissions,
    settlement: settlement,
  );
}

ChallengeSettlementSummary buildSettlement({
  String challengeId = 'challenge-1',
  String matchId = 'fixture-1',
  int officialHomeScore = 2,
  int officialAwayScore = 1,
  int winnersCount = 1,
  int losersCount = 2,
  int totalPoolFet = 9000,
  int losersPoolFet = 6000,
  int payoutPerWinnerFet = 9000,
  String settlementMode = 'exact_score',
}) {
  return ChallengeSettlementSummary(
    challengeId: challengeId,
    matchId: matchId,
    officialHomeScore: officialHomeScore,
    officialAwayScore: officialAwayScore,
    winnersCount: winnersCount,
    losersCount: losersCount,
    totalPoolFet: totalPoolFet,
    losersPoolFet: losersPoolFet,
    payoutPerWinnerFet: payoutPerWinnerFet,
    settlementMode: settlementMode,
    executedAt: DateTime.utc(2026, 4, 21, 18),
  );
}

ChallengeDetailPayload buildDetail({
  Challenge? challenge,
  List<ChallengeEntry>? entries,
}) {
  final resolvedChallenge = challenge ?? buildChallenge();
  return ChallengeDetailPayload(
    challenge: resolvedChallenge,
    entries:
        entries ??
        <ChallengeEntry>[
          buildEntry(
            challengeId: resolvedChallenge.id,
            homeScore: resolvedChallenge.creatorPrediction?.homeScore ?? 2,
            awayScore: resolvedChallenge.creatorPrediction?.awayScore ?? 1,
            userId: resolvedChallenge.creatorUserId,
            userName: resolvedChallenge.creatorDisplayName,
            stakeFet: resolvedChallenge.stakeFet,
          ),
        ],
  );
}

FetWalletSummary buildWallet({int balance = 5000}) {
  return FetWalletSummary(
    userId: 'supporter-1',
    clubId: 24,
    membershipId: 'membership-1',
    balance: balance,
    tier: 'gold',
    weeklyEarned: 200,
    monthlyEarned: 480,
    lifetimeEarned: 1600,
    lifetimeSpent: 350,
    transactionCount: 3,
    historicalBalanceGap: 0,
  );
}

Future<void> pumpTestWidget(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const <Override>[],
  Locale? locale,
  Size size = const Size(393, 852),
  double textScaleFactor = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: locale == null
            ? child
            : AfriLocalizationsScope(locale: locale, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
