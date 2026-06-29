import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────────────
  // ChallengeUser
  // ─────────────────────────────────────────────────────────────

  group('ChallengeUser', () {
    test('fromJson parses all fields', () {
      final user = ChallengeUser.fromJson({
        'id': 'u1',
        'display_name': 'Jean',
        'avatar_url': 'https://cdn.example.com/avatar.png',
      });
      expect(user.id, 'u1');
      expect(user.displayName, 'Jean');
      expect(user.avatarUrl, 'https://cdn.example.com/avatar.png');
    });

    test('defaults display name to Supporter', () {
      final user = ChallengeUser.fromJson({'id': 'u2'});
      expect(user.displayName, 'Supporter');
      expect(user.avatarUrl, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // ChallengePermissions
  // ─────────────────────────────────────────────────────────────

  group('ChallengePermissions', () {
    test('fromJson parses all boolean fields', () {
      final perms = ChallengePermissions.fromJson({
        'has_joined': true,
        'is_creator': true,
        'can_join': false,
        'can_cancel': true,
        'can_retry_settlement': false,
      });
      expect(perms.hasJoined, true);
      expect(perms.isCreator, true);
      expect(perms.canJoin, false);
      expect(perms.canCancel, true);
      expect(perms.canRetrySettlement, false);
    });

    test('defaults all to false for empty JSON', () {
      final perms = ChallengePermissions.fromJson({});
      expect(perms.hasJoined, false);
      expect(perms.isCreator, false);
      expect(perms.canJoin, false);
      expect(perms.canCancel, false);
      expect(perms.canRetrySettlement, false);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // ChallengeEntry
  // ─────────────────────────────────────────────────────────────

  group('ChallengeEntry', () {
    test('fromJson parses entry with embedded user', () {
      final entry = ChallengeEntry.fromJson({
        'id': 'e1',
        'challenge_id': 'c1',
        'user_id': 'u1',
        'predicted_home_score': 2,
        'predicted_away_score': 1,
        'stake_fet': 500,
        'status': 'winner',
        'payout_fet': 1500,
        'user': {'id': 'u1', 'display_name': 'Jean'},
      });

      expect(entry.id, 'e1');
      expect(entry.predictedHomeScore, 2);
      expect(entry.predictedAwayScore, 1);
      expect(entry.stakeFet, 500);
      expect(entry.status, ChallengeEntryStatus.winner);
      expect(entry.isWinner, true);
      expect(entry.isLoser, false);
      expect(entry.payoutFet, 1500);
      expect(entry.user, isNotNull);
      expect(entry.displayName, 'Jean');
    });

    test('displayName falls back through user hierarchy', () {
      // With userName override
      final withName = ChallengeEntry.fromJson({
        'user_name': 'Eric',
        'user': {'id': 'u1', 'display_name': 'Jean'},
      });
      expect(withName.displayName, 'Eric');

      // Without userName but with user
      final withUser = ChallengeEntry.fromJson({
        'user': {'id': 'u1', 'display_name': 'Jean'},
      });
      expect(withUser.displayName, 'Jean');

      // Without both
      final withNeither = ChallengeEntry.fromJson({});
      expect(withNeither.displayName, 'Supporter');
    });

    test('status parsing for all values', () {
      for (final entry in {
        'active': ChallengeEntryStatus.active,
        'winner': ChallengeEntryStatus.winner,
        'loser': ChallengeEntryStatus.loser,
        'refunded': ChallengeEntryStatus.refunded,
        'cancelled': ChallengeEntryStatus.cancelled,
      }.entries) {
        final result = ChallengeEntry.fromJson({'status': entry.key});
        expect(
          result.status,
          entry.value,
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });

    test('unknown status defaults to active', () {
      final entry = ChallengeEntry.fromJson({'status': 'unknown'});
      expect(entry.status, ChallengeEntryStatus.active);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // ChallengeSettlementSummary
  // ─────────────────────────────────────────────────────────────

  group('ChallengeSettlementSummary', () {
    test('fromJson parses settlement data', () {
      final settlement = ChallengeSettlementSummary.fromJson({
        'challenge_id': 'c1',
        'match_id': 'm1',
        'official_home_score': 2,
        'official_away_score': 1,
        'winners_count': 3,
        'losers_count': 7,
        'total_pool_fet': 5000,
        'losers_pool_fet': 3500,
        'payout_per_winner_fet': 1167,
        'settlement_mode': 'exact_score',
        'metadata': {'rule': 'penalty_shootout_excluded'},
      });

      expect(settlement.officialHomeScore, 2);
      expect(settlement.officialAwayScore, 1);
      expect(settlement.winnersCount, 3);
      expect(settlement.losersCount, 7);
      expect(settlement.totalPoolFet, 5000);
      expect(settlement.payoutPerWinnerFet, 1167);
      expect(settlement.settlementMode, 'exact_score');
      expect(settlement.metadata['rule'], 'penalty_shootout_excluded');
    });

    test('handles non-Map metadata gracefully', () {
      final settlement = ChallengeSettlementSummary.fromJson({
        'metadata': 'invalid',
      });
      expect(settlement.metadata, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Challenge
  // ─────────────────────────────────────────────────────────────

  group('Challenge', () {
    test('fromJson parses full challenge with nested objects', () {
      final futureDate = DateTime.now().add(const Duration(hours: 2));
      final challenge = Challenge.fromJson({
        'id': 'c1',
        'club_id': 24,
        'match_id': 'm1',
        'creator_user_id': 'u1',
        'stake_fet': 500,
        'status': 'open',
        'lock_at': futureDate.toIso8601String(),
        'total_participants': 5,
        'total_pool_fet': 2500,
        'permissions': {
          'has_joined': false,
          'can_join': true,
          'is_creator': false,
        },
        'creator': {'id': 'u1', 'display_name': 'Jean'},
      });

      expect(challenge.id, 'c1');
      expect(challenge.clubId, 24);
      expect(challenge.stakeFet, 500);
      expect(challenge.status, ChallengeStatus.open);
      expect(challenge.isOpen, true); // lock_at is in the future
      expect(challenge.isLocked, false);
      expect(challenge.canJoin, true);
      expect(challenge.isCreator, false);
      expect(challenge.creatorDisplayName, 'Jean');
    });

    test('status parsing for all values', () {
      for (final entry in {
        'open': ChallengeStatus.open,
        'locked': ChallengeStatus.locked,
        'settled': ChallengeStatus.settled,
        'void': ChallengeStatus.void_,
        'cancelled': ChallengeStatus.cancelled,
      }.entries) {
        final result = Challenge.fromJson({'status': entry.key});
        expect(
          result.status,
          entry.value,
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });

    test('unknown status defaults to open', () {
      final challenge = Challenge.fromJson({'status': 'draft'});
      expect(challenge.status, ChallengeStatus.open);
    });

    test('isLocked when lock_at is in the past', () {
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));
      final challenge = Challenge.fromJson({
        'status': 'open',
        'lock_at': pastDate.toIso8601String(),
      });
      expect(challenge.isLocked, true); // open but past lock_at
      expect(challenge.isOpen, false);
    });

    test('isSettled and isVoid and isCancelled', () {
      expect(Challenge.fromJson({'status': 'settled'}).isSettled, true);
      expect(Challenge.fromJson({'status': 'void'}).isVoid, true);
      expect(Challenge.fromJson({'status': 'cancelled'}).isCancelled, true);
    });

    test('creatorDisplayName fallback chain', () {
      // With creatorName
      final withName = Challenge.fromJson({'creator_name': 'Eric'});
      expect(withName.creatorDisplayName, 'Eric');

      // Without creatorName but with creator
      final withCreator = Challenge.fromJson({
        'creator': {'id': 'u1', 'display_name': 'Jean'},
      });
      expect(withCreator.creatorDisplayName, 'Jean');

      // Without both
      final withNeither = Challenge.fromJson({});
      expect(withNeither.creatorDisplayName, 'Supporter');
    });
  });

  // ─────────────────────────────────────────────────────────────
  // ChallengeMutationResult
  // ─────────────────────────────────────────────────────────────

  group('ChallengeMutationResult', () {
    test('recognizes success statuses', () {
      for (final status in [
        'created',
        'joined',
        'cancelled',
        'already_joined',
        'already_processed',
      ]) {
        final result = ChallengeMutationResult.fromJson({'status': status});
        expect(result.isSuccess, true, reason: '$status should be success');
      }
    });

    test('error status is not success', () {
      final result = ChallengeMutationResult.fromJson({'status': 'error'});
      expect(result.isSuccess, false);
    });

    test('defaults to error on missing status', () {
      final result = ChallengeMutationResult.fromJson({});
      expect(result.status, 'error');
      expect(result.isSuccess, false);
    });
  });
}
