import 'package:feat_gamification/src/models/partner_pool_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PartnerPredictionPool', () {
    test('parses partner-centered WDW pool payload', () {
      final pool = PartnerPredictionPool.fromJson({
        'id': 'pool-1',
        'club_id': 24,
        'partner_id': 'partner-1',
        'partner_name': 'Partner Bank',
        'partner_slug': 'partner-bank',
        'initiative_id': 'initiative-1',
        'fixture_id': 'fixture-1',
        'title': 'Derby WDW Pool',
        'partner_stake_fet': 5000,
        'fan_entry_fet': 100,
        'eligibility_mode': 'initiative_earn_required',
        'status': 'open',
        'lock_at': '2026-07-01T15:00:00Z',
        'total_entries': 14,
        'total_fan_entry_fet': 1400,
        'viewer_entry': {
          'id': 'entry-1',
          'selected_outcome': 'home_win',
          'eligibility_status': 'eligible',
          'status': 'active',
          'payout_fet': 0,
          'refunded_fet': 0,
          'joined_at': '2026-07-01T10:00:00Z',
        },
      });

      expect(pool.id, 'pool-1');
      expect(pool.partnerStakeFet, 5000);
      expect(pool.fanEntryFet, 100);
      expect(pool.eligibilityLabel, 'Promotion earn required');
      expect(pool.hasJoined, true);
      expect(pool.viewerEntry?.selectedOutcome, PartnerPoolOutcome.homeWin);
    });

    test('parses WDW settlement summary', () {
      final pool = PartnerPredictionPool.fromJson({
        'id': 'pool-1',
        'club_id': 24,
        'partner_id': 'partner-1',
        'partner_name': 'Partner Bank',
        'partner_slug': 'partner-bank',
        'fixture_id': 'fixture-1',
        'title': 'Derby WDW Pool',
        'partner_stake_fet': 5000,
        'fan_entry_fet': 100,
        'eligibility_mode': 'open_to_all',
        'status': 'settled',
        'lock_at': '2026-07-01T15:00:00Z',
        'total_entries': 10,
        'total_fan_entry_fet': 1000,
        'settlement': {
          'official_outcome': 'draw',
          'logical_winners': 4,
          'eligible_winners': 3,
          'ineligible_winners': 1,
          'total_paid_fet': 6000,
          'total_refunded_fet': 100,
          'unawarded_partner_fet': 0,
          'settlement_mode': 'wdw_settled',
          'settled_at': '2026-07-01T17:00:00Z',
        },
      });

      expect(pool.settlement?.officialOutcome, PartnerPoolOutcome.draw);
      expect(pool.settlement?.eligibleWinners, 3);
      expect(pool.settlement?.totalPaidFet, 6000);
      expect(pool.settlement?.settlementMode, 'wdw_settled');
    });
  });

  group('PartnerPoolMutationResult', () {
    test('wraps joined pool response', () {
      final result = PartnerPoolMutationResult.fromJson({
        'mutation_status': 'success',
        'id': 'pool-1',
        'club_id': 24,
        'partner_id': 'partner-1',
        'partner_name': 'Partner Bank',
        'partner_slug': 'partner-bank',
        'fixture_id': 'fixture-1',
        'title': 'Derby WDW Pool',
        'partner_stake_fet': 5000,
        'fan_entry_fet': 100,
        'eligibility_mode': 'partner_earn_required',
        'status': 'open',
        'lock_at': '2026-07-01T15:00:00Z',
        'total_entries': 1,
        'total_fan_entry_fet': 100,
      });

      expect(result.status, 'success');
      expect(result.pool?.eligibilityLabel, 'Partner earn required');
      expect(result.pool?.fanEntryFet, 100);
    });
  });
}
