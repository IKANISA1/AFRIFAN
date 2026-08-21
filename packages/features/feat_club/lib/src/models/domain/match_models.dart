import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';

/// A single match fixture.
class ClubMatch extends Equatable {
  const ClubMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.competition,
    required this.venue,
    required this.matchDate,
    required this.kickoffTime,
    required this.isOnSale,
    required this.ticketGeneralPrice,
    required this.ticketVipPrice,
    required this.saleStartsAt,
    required this.capacity,
    this.soldCount = 0,
    this.imageUrl,
    this.roster = const <String>[],
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final String competition;
  final String venue;
  final DateTime matchDate;
  final String kickoffTime;
  final bool isOnSale;
  final int ticketGeneralPrice;
  final int ticketVipPrice;
  final DateTime saleStartsAt;
  final int capacity;
  final int soldCount;
  final String? imageUrl;
  final List<String> roster;

  bool get isSoldOut => capacity > 0 && soldCount >= capacity;
  int get remainingCapacity =>
      capacity > 0 ? (capacity - soldCount).clamp(0, capacity) : 0;

  /// Tier-gated early access.
  bool isAccessibleForTier(jh.FanTier tier) {
    if (!isOnSale || capacity <= 0 || isSoldOut) return false;
    final accessStart = switch (tier) {
      jh.FanTier.gold => saleStartsAt.subtract(const Duration(hours: 48)),
      jh.FanTier.silver => saleStartsAt.subtract(const Duration(hours: 48)),
      jh.FanTier.bronze => saleStartsAt.subtract(const Duration(hours: 24)),
      jh.FanTier.imena ||
      jh.FanTier.inyamibwa ||
      jh.FanTier.ingenziImanzi => saleStartsAt,
    };
    return !DateTime.now().isBefore(accessStart);
  }

  factory ClubMatch.fromJson(Map<String, dynamic> json) {
    final matchDate = jh.parseDateTime(json['match_date']) ?? DateTime.now();
    return ClubMatch(
      id: jh.asStringOrNull(json['id']) ?? '',
      homeTeam: jh.asStringOrNull(json['home_team']) ?? 'Home',
      awayTeam: jh.asStringOrNull(json['away_team']) ?? 'Away',
      competition: jh.asStringOrNull(json['competition']) ?? 'League',
      venue: jh.asStringOrNull(json['venue']) ?? 'Stadium',
      matchDate: matchDate,
      kickoffTime: jh.asStringOrNull(json['kickoff_time']) ?? 'TBD',
      isOnSale: jh.asBool(json['is_on_sale']),
      ticketGeneralPrice: jh.asInt(json['ticket_general_price']),
      ticketVipPrice: jh.asInt(json['ticket_vip_price']),
      saleStartsAt:
          jh.parseDateTime(json['sale_starts_at']) ??
          matchDate.subtract(const Duration(days: 7)),
      capacity: jh.asInt(json['capacity']),
      soldCount: jh.asInt(json['sold_count']),
      imageUrl: jh.asStringOrNull(json['image_url']),
      roster:
          (json['roster'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'home_team': homeTeam,
    'away_team': awayTeam,
    'competition': competition,
    'venue': venue,
    'match_date': matchDate.toIso8601String(),
    'kickoff_time': kickoffTime,
    'is_on_sale': isOnSale,
    'ticket_general_price': ticketGeneralPrice,
    'ticket_vip_price': ticketVipPrice,
    'sale_starts_at': saleStartsAt.toIso8601String(),
    'capacity': capacity,
    'sold_count': soldCount,
    'image_url': imageUrl,
    'roster': roster,
  };

  @override
  List<Object?> get props => [
    id,
    homeTeam,
    awayTeam,
    competition,
    venue,
    matchDate,
    isOnSale,
    capacity,
    soldCount,
  ];
}

/// A purchased ticket tied to a match.
class ClubTicket extends Equatable {
  /// Least-privilege Data API projection shared by every supporter ticket
  /// reader. Keep this aligned with the column grants in the ticket boundary
  /// migration; internal audit and mock-fixture fields are intentionally absent.
  static const dataApiProjection = '''
    id,
    match_id,
    user_id,
    seat_type,
    amount_paid,
    qr_code,
    momo_reference,
    status,
    purchased_at,
    updated_at,
    club_id,
    created_at,
    confirmed_at,
    match:matches(
      id,
      home_team,
      away_team,
      competition,
      venue,
      match_date,
      kickoff_time,
      is_on_sale,
      ticket_general_price,
      ticket_vip_price,
      sale_starts_at,
      capacity,
      sold_count,
      image_url,
      roster,
      club_id
    )
  ''';

  const ClubTicket({
    required this.id,
    required this.matchId,
    required this.match,
    required this.userId,
    required this.seatType,
    required this.amountPaid,
    required this.qrCode,
    required this.paymentReference,
    required this.status,
    required this.purchasedAt,
    required this.updatedAt,
  });

  final String id;
  final String matchId;
  final ClubMatch match;
  final String userId;
  final jh.SeatType seatType;
  final int amountPaid;
  final String qrCode;
  final String paymentReference;
  final jh.TicketStatus status;
  final DateTime purchasedAt;
  final DateTime updatedAt;

  String get matchTitle => '${match.homeTeam} vs ${match.awayTeam}';

  factory ClubTicket.fromJson(Map<String, dynamic> json) {
    final nestedMatch = json['match'] as Map<String, dynamic>?;
    final purchasedAt =
        jh.parseDateTime(json['purchased_at']) ?? DateTime.now();
    return ClubTicket(
      id: jh.asStringOrNull(json['id']) ?? '',
      matchId: jh.asStringOrNull(json['match_id']) ?? '',
      match: nestedMatch != null
          ? ClubMatch.fromJson(nestedMatch)
          : ClubMatch.fromJson(json),
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      seatType: jh.SeatTypeX.fromValue(json['seat_type']?.toString()),
      amountPaid: jh.asInt(json['amount_paid']),
      qrCode: jh.asStringOrNull(json['qr_code']) ?? '',
      paymentReference: jh.asStringOrNull(json['momo_reference']) ?? '',
      status: jh.TicketStatusX.fromValue(json['status']?.toString()),
      purchasedAt: purchasedAt,
      updatedAt: jh.parseDateTime(json['updated_at']) ?? purchasedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    matchId,
    userId,
    seatType,
    amountPaid,
    status,
    purchasedAt,
    updatedAt,
  ];
}
