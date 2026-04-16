import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for ticket models — ClubMatch, ClubTicket
/// and their tier-gated access logic.
void main() {
  // ═══════════════════════════════════════════════════════════
  // ClubMatch Model
  // ═══════════════════════════════════════════════════════════

  group('ClubMatch.fromJson', () {
    final validJson = {
      'id': 'match-1',
      'home_team': 'Rayon Sports',
      'away_team': 'Rayon Sports FC',
      'competition': 'Rwanda Premier League',
      'venue': 'Amahoro Stadium',
      'match_date': '2026-04-15T15:00:00Z',
      'kickoff_time': '15:00',
      'is_on_sale': true,
      'ticket_general_price': 2000,
      'ticket_vip_price': 10000,
      'sale_starts_at': '2026-04-08T00:00:00Z',
      'capacity': 25000,
      'sold_count': 5000,
      'image_url': 'https://example.com/match.jpg',
      'roster': ['Player A', 'Player B'],
    };

    test('parses all fields correctly', () {
      final match = ClubMatch.fromJson(validJson);
      expect(match.id, 'match-1');
      expect(match.homeTeam, 'Rayon Sports');
      expect(match.awayTeam, 'Rayon Sports FC');
      expect(match.competition, 'Rwanda Premier League');
      expect(match.venue, 'Amahoro Stadium');
      expect(match.kickoffTime, '15:00');
      expect(match.isOnSale, isTrue);
      expect(match.ticketGeneralPrice, 2000);
      expect(match.ticketVipPrice, 10000);
      expect(match.capacity, 25000);
      expect(match.soldCount, 5000);
      expect(match.imageUrl, 'https://example.com/match.jpg');
      expect(match.roster, hasLength(2));
    });

    test('handles minimal/null fields gracefully', () {
      final match = ClubMatch.fromJson({});
      expect(match.id, '');
      expect(match.homeTeam, 'Home');
      expect(match.awayTeam, 'Away');
      expect(match.competition, 'League');
      expect(match.venue, 'Stadium');
      expect(match.kickoffTime, 'TBD');
      expect(match.isOnSale, isFalse);
      expect(match.roster, isEmpty);
    });

    test('isSoldOut returns true when sold >= capacity', () {
      final soldOut = ClubMatch.fromJson({
        ...validJson,
        'sold_count': 25000,
      });
      expect(soldOut.isSoldOut, isTrue);
      expect(soldOut.remainingCapacity, 0);
    });

    test('remainingCapacity is correct', () {
      final match = ClubMatch.fromJson(validJson);
      expect(match.remainingCapacity, 20000); // 25000 - 5000
    });

    test('toJson round-trips correctly', () {
      final match = ClubMatch.fromJson(validJson);
      final json = match.toJson();
      final roundTripped = ClubMatch.fromJson(json);
      expect(roundTripped.id, match.id);
      expect(roundTripped.homeTeam, match.homeTeam);
      expect(roundTripped.ticketGeneralPrice, match.ticketGeneralPrice);
    });
  });

  group('ClubMatch.isAccessibleForTier', () {
    ClubMatch matchWithSaleStart(DateTime saleStart) {
      return ClubMatch.fromJson({
        'id': 'match-tier',
        'home_team': 'Rayon',
        'away_team': 'Rayon Sports',
        'competition': 'League',
        'venue': 'Stadium',
        'match_date': saleStart.add(const Duration(days: 7)).toIso8601String(),
        'kickoff_time': '15:00',
        'is_on_sale': true,
        'ticket_general_price': 2000,
        'ticket_vip_price': 10000,
        'sale_starts_at': saleStart.toIso8601String(),
        'capacity': 25000,
        'sold_count': 0,
      });
    }

    test('fan tier can only access after sale_starts_at', () {
      // Sale starts in the future
      final futureSale = matchWithSaleStart(
        DateTime.now().add(const Duration(days: 1)),
      );
      expect(futureSale.isAccessibleForTier(FanTier.fan), isFalse);

      // Sale started in the past
      final pastSale = matchWithSaleStart(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(pastSale.isAccessibleForTier(FanTier.fan), isTrue);
    });

    test('platinum gets 72h early access', () {
      // Sale starts 60h from now — platinum (72h early) should have access
      // but gold (48h early) should NOT
      final match = matchWithSaleStart(
        DateTime.now().add(const Duration(hours: 60)),
      );
      expect(match.isAccessibleForTier(FanTier.platinum), isTrue);
      expect(match.isAccessibleForTier(FanTier.gold), isFalse);
      expect(match.isAccessibleForTier(FanTier.bronze), isFalse);
      expect(match.isAccessibleForTier(FanTier.fan), isFalse);
    });

    test('sold out match is not accessible to any tier', () {
      final soldOut = ClubMatch.fromJson({
        'id': 'sold-out',
        'is_on_sale': true,
        'capacity': 100,
        'sold_count': 100,
        'sale_starts_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'match_date':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      for (final tier in FanTier.values) {
        expect(soldOut.isAccessibleForTier(tier), isFalse);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ClubTicket Model
  // ═══════════════════════════════════════════════════════════

  group('ClubTicket.fromJson', () {
    test('parses ticket with nested match', () {
      final ticket = ClubTicket.fromJson({
        'id': 'ticket-1',
        'match_id': 'match-1',
        'match': {
          'id': 'match-1',
          'home_team': 'Rayon Sports',
          'away_team': 'Rayon Sports FC',
          'match_date': '2026-04-15T15:00:00Z',
          'is_on_sale': true,
          'capacity': 25000,
        },
        'user_id': 'user-1',
        'seat_type': 'vip',
        'amount_paid': 10000,
        'qr_code': 'RS-123456',
        'momo_reference': 'MOMO-REF-001',
        'status': 'active',
        'purchased_at': '2026-04-01T10:00:00Z',
      });

      expect(ticket.id, 'ticket-1');
      expect(ticket.matchId, 'match-1');
      expect(ticket.userId, 'user-1');
      expect(ticket.seatType, SeatType.vip);
      expect(ticket.amountPaid, 10000);
      expect(ticket.qrCode, 'RS-123456');
      expect(ticket.paymentReference, 'MOMO-REF-001');
      expect(ticket.status, TicketStatus.active);
    });

    test('matchTitle combines team names', () {
      final ticket = ClubTicket.fromJson({
        'id': 'ticket-2',
        'match_id': 'match-2',
        'match': {
          'id': 'match-2',
          'home_team': 'Rayon',
          'away_team': 'Rayon Sports',
          'match_date': '2026-05-01T15:00:00Z',
        },
        'user_id': 'user-1',
        'seat_type': 'general',
        'amount_paid': 2000,
        'status': 'active',
      });

      expect(ticket.matchTitle, 'Rayon vs Rayon Sports');
    });

    test('parses ticket without nested match (fallback)', () {
      final ticket = ClubTicket.fromJson({
        'id': 'ticket-3',
        'match_id': 'match-3',
        'home_team': 'Rayon',
        'away_team': 'Rayon Sports',
        'match_date': '2026-05-01T15:00:00Z',
        'user_id': 'user-1',
        'seat_type': 'general',
        'amount_paid': 2000,
        'status': 'cancelled',
      });

      expect(ticket.status, TicketStatus.cancelled);
      expect(ticket.match.homeTeam, 'Rayon');
    });

    test('defaults seat_type to general for unknown value', () {
      final ticket = ClubTicket.fromJson({
        'id': 't-4',
        'match_id': 'm-4',
        'match': {
          'id': 'm-4',
          'match_date': '2026-05-01T15:00:00Z',
        },
        'user_id': 'u-1',
        'seat_type': 'premium_lounge',
        'amount_paid': 50000,
        'status': 'active',
      });
      expect(ticket.seatType, SeatType.general);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // FanMembership Model
  // ═══════════════════════════════════════════════════════════

  group('FanMembership', () {
    test('fromJson parses correctly', () {
      final m = FanMembership.fromJson({
        'id': 'mem-1',
        'user_id': 'user-1',
        'partner_id': 'rayon_sports_rw',
        'display_name': 'Jean',
        'tier': 'gold',
        'points': 3500,
        'chapter': 'Kigali',
        'membership_number': 'FAN-001',
        'joined_at': '2025-01-01T00:00:00Z',
      });

      expect(m.id, 'mem-1');
      expect(m.tier, FanTier.gold);
      expect(m.points, 3500);
      expect(m.chapter, 'Kigali');
    });

    test('nextTierPoints is correct per tier', () {
      final fan = FanMembership.fromJson({
        'user_id': 'u',
        'partner_id': 'p',
        'tier': 'fan',
        'points': 500,
        'chapter': 'Main',
        'membership_number': 'FAN-1',
        'joined_at': '2025-01-01T00:00:00Z',
      });
      expect(fan.nextTierPoints, 1000);

      final gold = FanMembership.fromJson({
        'user_id': 'u',
        'partner_id': 'p',
        'tier': 'gold',
        'points': 3000,
        'chapter': 'Main',
        'membership_number': 'FAN-2',
        'joined_at': '2025-01-01T00:00:00Z',
      });
      expect(gold.nextTierPoints, 5000);
    });

    test('platinum has 0 pointsToNextTier', () {
      final plat = FanMembership.fromJson({
        'user_id': 'u',
        'partner_id': 'p',
        'tier': 'platinum',
        'points': 8000,
        'chapter': 'Main',
        'membership_number': 'FAN-3',
        'joined_at': '2025-01-01T00:00:00Z',
      });
      expect(plat.pointsToNextTier, 0);
      expect(plat.progressToNextTier, 1.0);
    });

    test('isExpired checks expiresAt', () {
      final expired = FanMembership.fromJson({
        'user_id': 'u',
        'partner_id': 'p',
        'tier': 'fan',
        'points': 0,
        'chapter': 'Main',
        'membership_number': 'FAN-4',
        'joined_at': '2025-01-01T00:00:00Z',
        'expires_at': '2020-01-01T00:00:00Z',
      });
      expect(expired.isExpired, isTrue);
    });
  });
}
