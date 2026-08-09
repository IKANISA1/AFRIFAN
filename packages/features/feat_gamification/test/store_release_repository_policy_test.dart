import 'package:core_feature_config/core_feature_config.dart';
import 'package:feat_gamification/src/repositories/challenge_repository.dart';
import 'package:feat_gamification/src/repositories/fet_repository.dart';
import 'package:feat_gamification/src/repositories/partner_pool_repository.dart';
import 'package:feat_gamification/src/repositories/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  const policy = StoreReleasePolicy(isEnforced: true);

  group('store release repository policy', () {
    test(
      'challenge and pool reads fail closed without touching Supabase',
      () async {
        final client = _MockSupabaseClient();
        final challenges = ChallengeRepository(
          client: client,
          storeReleasePolicy: policy,
        );
        final pools = PartnerPoolRepository(
          client: client,
          storeReleasePolicy: policy,
        );

        expect(await challenges.loadChallenges(), isEmpty);
        expect(await challenges.loadMyChallenges(), isEmpty);
        expect(await challenges.loadChallengeDetail('challenge-1'), isNull);
        expect(await pools.loadPools(), isEmpty);
        verifyNever(() => client.auth);
      },
    );

    test('challenge and pool mutations reject before network access', () async {
      final client = _MockSupabaseClient();
      final challenges = ChallengeRepository(
        client: client,
        storeReleasePolicy: policy,
      );
      final pools = PartnerPoolRepository(
        client: client,
        storeReleasePolicy: policy,
      );

      await expectLater(
        challenges.createChallenge(
          matchId: 'match-1',
          homeScore: 1,
          awayScore: 0,
          stakeFet: 50,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        challenges.joinChallenge(
          challengeId: 'challenge-1',
          homeScore: 1,
          awayScore: 0,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        challenges.cancelChallenge('challenge-1'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        pools.joinPool(poolId: 'pool-1', selectedOutcome: 'home'),
        throwsA(isA<UnsupportedError>()),
      );
      verifyNever(() => client.auth);
    });

    test('reward catalog and value-moving mutations fail closed', () async {
      final client = _MockSupabaseClient();
      final repository = FetRepository(
        client: client,
        storeReleasePolicy: policy,
      );

      expect(await repository.loadPartnerOffers(), isEmpty);
      expect(await repository.loadRewardStoreItems(), isEmpty);
      await expectLater(
        repository.redeemReward(rewardItemId: 'reward-1'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        repository.transferFet(recipientUserId: 'user-2', amount: 10),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        repository.redeemFet(amount: 10),
        throwsA(isA<UnsupportedError>()),
      );
      verifyNever(() => client.auth);
    });

    test(
      'catalog authorization cannot open transfer or manual redemption rails',
      () async {
        final client = _MockSupabaseClient();
        const catalogAuthorizedPolicy = StoreReleasePolicy(
          isEnforced: true,
          rewardRedemptionAuthorized: true,
        );
        final repository = FetRepository(
          client: client,
          storeReleasePolicy: catalogAuthorizedPolicy,
        );

        await expectLater(
          repository.transferFet(recipientUserId: 'user-2', amount: 10),
          throwsA(isA<UnsupportedError>()),
        );
        await expectLater(
          repository.redeemFet(amount: 10),
          throwsA(isA<UnsupportedError>()),
        );
        verifyNever(() => client.auth);
      },
    );

    test('jackpot and friend challenge mutations fail closed', () async {
      final client = _MockSupabaseClient();
      final repository = PredictionRepository(
        client: client,
        storeReleasePolicy: policy,
      );

      expect(await repository.loadActiveJackpotRound(), isNull);
      await expectLater(
        repository.placeJackpotEntry(
          roundId: 'round-1',
          selections: const <Map<String, String>>[],
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        repository.createFriendChallenge(
          opponentUserId: 'user-2',
          fixtureMarketId: 'market-1',
          selectedOutcome: 'home',
          message: 'unmoderated text',
        ),
        throwsA(isA<UnsupportedError>()),
      );
      verifyNever(() => client.auth);
    });
  });
}
