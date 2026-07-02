import 'package:feat_gamification/src/models/fanzone_models.dart';
import 'package:feat_gamification/src/models/fet_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── FET Models ────────────────────────────────────────────────────────

  group('FetCatalogItem', () {
    test('parses valid JSON', () {
      final json = <String, dynamic>{
        'id': 'item-1',
        'club_id': '24',
        'code': 'g001',
        'template_scope': 'generic',
        'category': 'Fan Identity',
        'item_name': 'Complete Profile',
        'fet_value': 50,
        'trigger_condition': 'Set display name + alias',
        'activation_timing': 'Always on',
        'description': 'Complete your supporter profile.',
        'badge_name': 'Identity Hero',
        'implementation_notes': null,
        'sort_order': 1,
        'is_active': true,
      };

      final item = FetCatalogItem.fromJson(json);
      expect(item.id, 'item-1');
      expect(item.clubId, 24);
      expect(item.code, 'G001'); // uppercased
      expect(item.category, 'Fan Identity');
      expect(item.fetValue, 50);
      expect(item.isActive, isTrue);
      expect(item.badgeName, 'Identity Hero');
    });

    test('handles empty JSON defensively', () {
      final item = FetCatalogItem.fromJson(<String, dynamic>{});
      expect(item.id, '');
      expect(item.clubId, isNull);
      expect(item.code, '');
      expect(item.fetValue, 0);
      expect(item.isActive, isTrue); // defaults to true
    });

    group('iconKey', () {
      test('maps match category to match icon', () {
        final item = _catalogWith(category: 'Match Day Events');
        expect(item.iconKey, 'match');
      });

      test('maps social category to fan_club icon', () {
        final item = _catalogWith(category: 'Social Engagement');
        expect(item.iconKey, 'fan_club');
      });

      test('maps prediction category to mvp icon', () {
        final item = _catalogWith(category: 'Prediction');
        expect(item.iconKey, 'mvp');
      });

      test('defaults to match for unknown categories', () {
        final item = _catalogWith(category: 'Unknown');
        expect(item.iconKey, 'match');
      });
    });

    group('challengeBucket', () {
      test('daily for match day events', () {
        final item = _catalogWith(activationTiming: 'Match day only');
        expect(item.challengeBucket, FetChallengeBucket.daily);
      });

      test('seasonal for loyalty events', () {
        final item = _catalogWith(
          activationTiming: 'Season',
          category: 'Seasonal Award',
        );
        expect(item.challengeBucket, FetChallengeBucket.seasonal);
      });

      test('weekly for everything else', () {
        final item = _catalogWith(activationTiming: 'Ongoing');
        expect(item.challengeBucket, FetChallengeBucket.weekly);
      });
    });
  });

  group('FetLeaderboardRow', () {
    test('parses valid JSON', () {
      final json = <String, dynamic>{
        'rank': 1,
        'user_id': 'user-1',
        'supporter_alias': '123456',
        'display_name': 'Kagame Fan',
        'total_fet': 5000,
        'tier': 'gold',
        'is_current_user': true,
      };

      final row = FetLeaderboardRow.fromJson(json);
      expect(row.rank, 1);
      expect(row.displayName, 'Kagame Fan');
      expect(row.totalFet, 5000);
      expect(row.isCurrentUser, isTrue);
    });

    test('handles empty JSON', () {
      final row = FetLeaderboardRow.fromJson(<String, dynamic>{});
      expect(row.rank, 0);
      expect(row.userId, '');
      expect(row.displayName, 'Supporter');
      expect(row.isCurrentUser, isFalse);
    });
  });

  group('FetWalletSummary', () {
    test('parses valid JSON', () {
      final json = <String, dynamic>{
        'user_id': 'user-abc',
        'club_id': '24',
        'membership_id': 'mem-1',
        'balance': 2500,
        'tier': 'gold',
        'weekly_earned': 150,
        'monthly_earned': 600,
        'lifetime_earned': 3000,
        'lifetime_spent': 500,
        'transaction_count': 45,
        'historical_balance_gap': 0,
      };

      final wallet = FetWalletSummary.fromJson(json);
      expect(wallet.balance, 2500);
      expect(wallet.tier, 'gold');
      expect(wallet.lifetimeEarned, 3000);
      expect(wallet.transactionCount, 45);
    });
  });

  group('FetWalletTransaction', () {
    test('parses credit transaction', () {
      final json = <String, dynamic>{
        'id': 'tx-1',
        'entry_type': 'earn',
        'direction': 'credit',
        'amount': 100,
        'balance_after': 2600,
        'created_at': '2026-04-14T12:00:00Z',
      };

      final tx = FetWalletTransaction.fromJson(json);
      expect(tx.direction, FetWalletEntryDirection.credit);
      expect(tx.signedAmount, 100);
      expect(tx.headline, 'Points earned');
    });

    test('parses debit transaction', () {
      final json = <String, dynamic>{
        'id': 'tx-2',
        'entry_type': 'transfer_out',
        'direction': 'debit',
        'amount': 50,
        'balance_after': 2550,
        'counterparty_display_name': 'Friend',
        'counterparty_public_user_id': '654321',
      };

      final tx = FetWalletTransaction.fromJson(json);
      expect(tx.direction, FetWalletEntryDirection.debit);
      expect(tx.signedAmount, -50);
      expect(tx.headline, 'Transfer sent');
    });

    test('headline matches entry types', () {
      expect(_txWith('transfer_in').headline, 'Transfer received');
      expect(_txWith('transfer_out').headline, 'Transfer sent');
      expect(_txWith('redeem').headline, 'Points redemption');
      expect(
        _txWith('admin_adjustment', credit: true).headline,
        'Admin top-up',
      );
      expect(
        _txWith('admin_adjustment', credit: false).headline,
        'Admin deduction',
      );
      expect(_txWith('opening_balance').headline, 'Opening balance');
      expect(_txWith('earn').headline, 'Points earned');
      expect(_txWith('unknown_type').headline, 'Points earned'); // default
    });
  });

  group('FetWalletOperationResult', () {
    test('parses success response', () {
      final json = <String, dynamic>{
        'status': 'completed',
        'amount': 100,
        'balance': 2400,
        'reference_id': 'ref-1',
        'already_processed': false,
        'recipient_user_id': 'user-xyz',
      };

      final result = FetWalletOperationResult.fromJson(json);
      expect(result.status, 'completed');
      expect(result.amount, 100);
      expect(result.balance, 2400);
      expect(result.alreadyProcessed, isFalse);
    });

    test('parses idempotent dedup response', () {
      final json = <String, dynamic>{
        'status': 'duplicate',
        'amount': 100,
        'balance': 2400,
        'reference_id': 'ref-1',
        'already_processed': true,
      };

      final result = FetWalletOperationResult.fromJson(json);
      expect(result.alreadyProcessed, isTrue);
    });

    test('handles empty JSON', () {
      final result = FetWalletOperationResult.fromJson(<String, dynamic>{});
      expect(result.status, 'unknown');
      expect(result.amount, 0);
      expect(result.balance, 0);
    });
  });

  group('FetWalletSupporter', () {
    test('parses valid JSON', () {
      final json = <String, dynamic>{
        'user_id': 'user-match',
        'public_user_id': '789012',
        'display_name': 'Match Fan',
        'tier': 'bronze',
        'balance': 500,
      };

      final supporter = FetWalletSupporter.fromJson(json);
      expect(supporter.userId, 'user-match');
      expect(supporter.displayName, 'Match Fan');
      expect(supporter.balance, 500);
    });
  });

  // ── Fanzone Models ────────────────────────────────────────────────────

  group('CompetitionCatalogItem', () {
    test('parses valid JSON', () {
      final json = <String, dynamic>{
        'id': 'comp-1',
        'slug': 'rwanda-premier-league',
        'name': 'Rwanda Premier League',
        'short_name': 'RPL',
        'competition_kind': 'league',
        'region': 'East Africa',
        'country_code': 'RW',
        'country_name': 'Rwanda',
        'is_active': true,
      };

      final item = CompetitionCatalogItem.fromJson(json);
      expect(item.slug, 'rwanda-premier-league');
      expect(item.shortName, 'RPL');
      expect(item.isActive, isTrue);
    });

    test('handles empty JSON', () {
      final item = CompetitionCatalogItem.fromJson(<String, dynamic>{});
      expect(item.id, '');
      expect(item.slug, '');
      expect(item.name, '');
      expect(item.isActive, isTrue);
    });
  });

  // ── Prediction Models (supplementary) ─────────────────────────────────

  group('PredictionDashboard', () {
    test('empty() returns zeros', () {
      final dashboard = PredictionDashboard.empty();
      expect(dashboard.totalPredictions, 0);
      expect(dashboard.wonCount, 0);
      expect(dashboard.lostCount, 0);
      expect(dashboard.activeCount, 0);
      expect(dashboard.currentStreak, 0);
      expect(dashboard.winRate, 0);
    });

    test('parses full JSON and computes settledCount', () {
      final json = <String, dynamic>{
        'total_predictions': 50,
        'total_won': 30,
        'total_lost': 15,
        'total_pending': 5,
        'total_fet_earned': 3000,
        'current_streak': 7,
        'win_rate': 66.7,
      };

      final dashboard = PredictionDashboard.fromJson(json);
      expect(dashboard.totalPredictions, 50);
      expect(dashboard.settledCount, 45); // won + lost
      expect(dashboard.wonCount, 30);
      expect(dashboard.lostCount, 15);
      expect(dashboard.activeCount, 5);
    });
  });

  group('PredictionDetail', () {
    test('isSettled includes void_ status', () {
      final json = <String, dynamic>{
        'id': 'pred-v',
        'fixture_id': 'fix-v',
        'market_slug': '1x2',
        'market_name': '1X2',
        'market_short_name': '1X2',
        'competition_name': 'RPL',
        'home_team': 'Rayon',
        'home_team_short': 'RSP',
        'away_team': 'Rayon Sports',
        'away_team_short': 'Rayon Sports',
        'selected_outcome': 'home',
        'status': 'void',
        'fet_potential': 100,
        'fet_earned': 0,
      };

      final detail = PredictionDetail.fromJson(json);
      expect(detail.isSettled, isTrue);
      expect(detail.isPending, isFalse);
    });
  });
}

// ── Test Helpers ──────────────────────────────────────────────────────

FetCatalogItem _catalogWith({
  String category = 'General',
  String activationTiming = 'Always on',
}) {
  return FetCatalogItem.fromJson(<String, dynamic>{
    'id': 'test',
    'category': category,
    'activation_timing': activationTiming,
    'item_name': 'Test Item',
    'fet_value': 10,
    'is_active': true,
  });
}

FetWalletTransaction _txWith(String entryType, {bool credit = true}) {
  return FetWalletTransaction.fromJson(<String, dynamic>{
    'id': 'tx-test',
    'entry_type': entryType,
    'direction': credit ? 'credit' : 'debit',
    'amount': 10,
    'balance_after': 100,
  });
}
