import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';

const Object _unset = Object();

// ═══════════════════════════════════════════════════════════════
// Fan Membership
// ═══════════════════════════════════════════════════════════════

/// Universal fan membership — white-label, club-agnostic.
class FanMembership extends Equatable {
  const FanMembership({
    this.id = '',
    required this.userId,
    required this.partnerId,
    this.displayName = 'Fan',
    required this.tier,
    required this.points,
    required this.chapter,
    required this.membershipNumber,
    required this.joinedAt,
    this.expiresAt,
    this.renewedAt,
  });

  final String id;
  final String userId;
  final String partnerId;
  final String displayName;
  final jh.FanTier tier;
  final int points;
  final String chapter;
  final String membershipNumber;
  final DateTime joinedAt;
  final DateTime? expiresAt;
  final DateTime? renewedAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  int get nextTierPoints => switch (tier) {
        jh.FanTier.fan => 1000,
        jh.FanTier.bronze => 2000,
        jh.FanTier.gold => 5000,
        jh.FanTier.platinum => points,
      };

  int get pointsToNextTier => switch (tier) {
        jh.FanTier.platinum => 0,
        _ => (nextTierPoints - points).clamp(0, nextTierPoints),
      };

  double get progressToNextTier {
    if (tier == jh.FanTier.platinum) return 1;
    final floor = tier.minPoints;
    final span = nextTierPoints - floor;
    if (span <= 0) return 1;
    return ((points - floor) / span).clamp(0, 1).toDouble();
  }

  factory FanMembership.fromJson(Map<String, dynamic> json) {
    final points = jh.asInt(json['points']);
    final tier = json['tier'] == null
        ? jh.FanTierX.fromPoints(points)
        : jh.FanTierX.fromValue(json['tier']?.toString());

    return FanMembership(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']) ?? '',
      displayName: jh.asStringOrNull(json['display_name']) ?? 'Fan',
      tier: tier,
      points: points,
      chapter: jh.asStringOrNull(json['chapter']) ?? 'Main',
      membershipNumber: jh.asStringOrNull(json['membership_number']) ?? '',
      joinedAt: jh.parseDateTime(json['joined_at']) ?? DateTime.now(),
      expiresAt: jh.parseDateTime(json['expires_at']),
      renewedAt: jh.parseDateTime(json['renewed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'partner_id': partnerId,
        'display_name': displayName,
        'tier': tier.value,
        'points': points,
        'chapter': chapter,
        'membership_number': membershipNumber,
        'joined_at': joinedAt.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
        if (renewedAt != null) 'renewed_at': renewedAt!.toIso8601String(),
      };

  FanMembership copyWith({
    String? id,
    String? userId,
    String? partnerId,
    String? displayName,
    jh.FanTier? tier,
    int? points,
    String? chapter,
    String? membershipNumber,
    DateTime? joinedAt,
    Object? expiresAt = _unset,
    Object? renewedAt = _unset,
  }) {
    return FanMembership(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      partnerId: partnerId ?? this.partnerId,
      displayName: displayName ?? this.displayName,
      tier: tier ?? this.tier,
      points: points ?? this.points,
      chapter: chapter ?? this.chapter,
      membershipNumber: membershipNumber ?? this.membershipNumber,
      joinedAt: joinedAt ?? this.joinedAt,
      expiresAt: identical(expiresAt, _unset)
          ? this.expiresAt
          : expiresAt as DateTime?,
      renewedAt: identical(renewedAt, _unset)
          ? this.renewedAt
          : renewedAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        partnerId,
        displayName,
        tier,
        points,
        chapter,
        membershipNumber,
        joinedAt,
        expiresAt,
        renewedAt,
      ];
}

// ═══════════════════════════════════════════════════════════════
// Fan Club (Chapter)
// ═══════════════════════════════════════════════════════════════

class FanClub extends Equatable {
  const FanClub({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.region,
    required this.description,
    required this.memberCount,
    required this.eventCount,
    required this.rating,
    this.bannerImageUrl,
  });

  final String id;
  final String partnerId;
  final String name;
  final String region;
  final String description;
  final int memberCount;
  final int eventCount;
  final double rating;
  final String? bannerImageUrl;

  factory FanClub.fromJson(Map<String, dynamic> json) {
    return FanClub(
      id: jh.asStringOrNull(json['id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']) ?? '',
      name: jh.asStringOrNull(json['name']) ?? '',
      region: jh.asStringOrNull(json['region']) ?? '',
      description: jh.asStringOrNull(json['description']) ?? '',
      memberCount: jh.asInt(json['member_count']),
      eventCount: jh.asInt(json['event_count']),
      rating: jh.asDouble(json['rating']),
      bannerImageUrl: jh.asStringOrNull(json['banner_image_url']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partner_id': partnerId,
        'name': name,
        'region': region,
        'description': description,
        'member_count': memberCount,
        'event_count': eventCount,
        'rating': rating,
        'banner_image_url': bannerImageUrl,
      };

  @override
  List<Object?> get props => [id, partnerId, name, region];
}

// ═══════════════════════════════════════════════════════════════
// Match & Tickets
// ═══════════════════════════════════════════════════════════════

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
      jh.FanTier.platinum => saleStartsAt.subtract(const Duration(hours: 72)),
      jh.FanTier.gold => saleStartsAt.subtract(const Duration(hours: 48)),
      jh.FanTier.bronze => saleStartsAt.subtract(const Duration(hours: 24)),
      jh.FanTier.fan => saleStartsAt,
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
      saleStartsAt: jh.parseDateTime(json['sale_starts_at']) ??
          matchDate.subtract(const Duration(days: 7)),
      capacity: jh.asInt(json['capacity']),
      soldCount: jh.asInt(json['sold_count']),
      imageUrl: jh.asStringOrNull(json['image_url']),
      roster: (json['roster'] as List?)?.map((e) => e.toString()).toList() ??
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

class ClubTicket extends Equatable {
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

  String get matchTitle => '${match.homeTeam} vs ${match.awayTeam}';

  factory ClubTicket.fromJson(Map<String, dynamic> json) {
    final nestedMatch = json['match'] as Map<String, dynamic>?;
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
      purchasedAt: jh.parseDateTime(json['purchased_at']) ?? DateTime.now(),
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
      ];
}

// ═══════════════════════════════════════════════════════════════
// Shop Product & Order
// ═══════════════════════════════════════════════════════════════

class ClubProduct extends Equatable {
  const ClubProduct({
    required this.id,
    required this.partnerId,
    required this.name,
    this.description = '',
    required this.category,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.isNew,
    this.imageUrl,
    this.availableSizes = const <String>[],
    this.badgeLabel,
    this.collection,
    this.sortOrder = 0,
  });

  final String id;
  final String partnerId;
  final String name;
  final String description;
  final jh.ProductCategory category;
  final int price;
  final int stock;
  final bool isActive;
  final bool isNew;
  final String? imageUrl;
  final List<String> availableSizes;
  final String? badgeLabel;
  final String? collection;
  final int sortOrder;

  int discountedPrice(double discountPct) {
    final normalized = discountPct.clamp(0, 100);
    return (price * (1 - normalized / 100)).round();
  }

  factory ClubProduct.fromJson(Map<String, dynamic> json) {
    return ClubProduct(
      id: jh.asStringOrNull(json['id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']) ?? '',
      name: jh.asStringOrNull(json['name']) ?? 'Shop Item',
      description: jh.asStringOrNull(json['description']) ?? '',
      category: jh.ProductCategoryX.fromValue(json['category']?.toString()),
      price: jh.asInt(json['price']),
      stock: jh.asInt(json['stock'], fallback: 99),
      isActive: jh.asBool(json['is_active'], fallback: true),
      isNew: jh.asBool(json['is_new']),
      imageUrl: jh.asStringOrNull(json['image_url']),
      availableSizes: (json['sizes'] as List?)
              ?.map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      badgeLabel: jh.asStringOrNull(json['badge_label']),
      collection: jh.asStringOrNull(json['collection']),
      sortOrder: jh.asInt(json['sort_order']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partner_id': partnerId,
        'name': name,
        'description': description,
        'category': category.value,
        'price': price,
        'stock': stock,
        'is_active': isActive,
        'is_new': isNew,
        'image_url': imageUrl,
        'sizes': availableSizes,
        'badge_label': badgeLabel,
        'collection': collection,
        'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [id, partnerId, name, category, price, stock];
}

class CartItem extends Equatable {
  const CartItem({
    required this.product,
    required this.quantity,
    this.selectedVariant,
  });

  final ClubProduct product;
  final int quantity;
  final String? selectedVariant;

  int get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity, String? selectedVariant}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      selectedVariant: selectedVariant ?? this.selectedVariant,
    );
  }

  @override
  List<Object?> get props => [product, quantity, selectedVariant];
}

class ClubShopOrder extends Equatable {
  const ClubShopOrder({
    required this.id,
    required this.userId,
    this.partnerId,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.total,
    required this.deliveryAddress,
    required this.paymentReference,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? partnerId;
  final List<CartItem> items;
  final int subtotal;
  final int discountAmount;
  final int deliveryFee;
  final int total;
  final String deliveryAddress;
  final String paymentReference;
  final jh.OrderStatus status;
  final DateTime createdAt;

  factory ClubShopOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final items = rawItems.whereType<Map<String, dynamic>>().map((item) {
      final productJson = item['product'] as Map<String, dynamic>? ?? item;
      return CartItem(
        product: ClubProduct.fromJson(productJson),
        quantity: jh.asInt(item['quantity'], fallback: 1).clamp(1, 9999),
        selectedVariant: jh.asStringOrNull(item['selected_variant']),
      );
    }).toList(growable: false);

    final subtotal = jh.asInt(json['subtotal']);
    final discount = jh.asInt(json['discount_amount']);
    final delivery = jh.asInt(json['delivery_fee']);

    return ClubShopOrder(
      id: jh.asStringOrNull(json['id']) ?? '',
      userId: jh.asStringOrNull(json['user_id']) ?? '',
      partnerId: jh.asStringOrNull(json['partner_id']),
      items: items,
      subtotal: subtotal,
      discountAmount: discount,
      deliveryFee: delivery,
      total: jh.asInt(json['total'], fallback: subtotal - discount + delivery),
      deliveryAddress: jh.asStringOrNull(json['delivery_address']) ?? '',
      paymentReference: jh.asStringOrNull(json['momo_reference']) ?? '',
      status: jh.OrderStatusX.fromValue(json['status']?.toString()),
      createdAt: jh.parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, userId, status, total, createdAt];
}

// ═══════════════════════════════════════════════════════════════
// Contribution Group
// ═══════════════════════════════════════════════════════════════

class ContributionGroup extends Equatable {
  const ContributionGroup({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    this.groupType = jh.ContributionGroupType.community,
    this.privacy = jh.GroupPrivacy.public,
    this.targetAmount = 0,
    this.currentTotal = 0,
    this.paymentRecipient,
    this.paymentRecipientType,
    this.deadline,
    this.isRecurring = false,
    this.isClosed = false,
    this.inviteCode,
    this.memberCount = 0,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final jh.ContributionGroupType groupType;
  final jh.GroupPrivacy privacy;
  final int targetAmount;
  final int currentTotal;
  final String? paymentRecipient;
  final jh.PaymentRecipientType? paymentRecipientType;
  final DateTime? deadline;
  final bool isRecurring;
  final bool isClosed;
  final String? inviteCode;
  final int memberCount;
  final DateTime createdAt;

  double get progress =>
      targetAmount > 0 ? (currentTotal / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get remaining => (targetAmount - currentTotal).clamp(0, targetAmount);
  bool get isExpired => deadline != null && deadline!.isBefore(DateTime.now());

  factory ContributionGroup.fromJson(Map<String, dynamic> json) {
    // Handle both legacy (is_closed) and new (is_active) schema
    final isClosed = json.containsKey('is_active')
        ? !(json['is_active'] as bool? ?? true) // is_active inverts is_closed
        : (json['is_closed'] as bool? ?? false);

    return ContributionGroup(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      groupType: jh.ContributionGroupTypeX.fromValue(
        json['group_type'] as String?,
      ),
      privacy: jh.GroupPrivacyX.fromValue(json['privacy'] as String?),
      targetAmount: jh.asInt(json['target_amount']),
      currentTotal: jh.asInt(json['current_total']),
      paymentRecipient: jh.asStringOrNull(json['momo_recipient_code']) ??
          jh.asStringOrNull(json['receiving_momo_code']) ??
          jh.asStringOrNull(json['momo_number']),
      paymentRecipientType: _parseRecipientType(
        json['momo_route_type']?.toString(),
      ),
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      isRecurring: json['is_recurring'] as bool? ?? false,
      isClosed: isClosed,
      inviteCode: json['invite_code'] as String?,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'description': description,
        'group_type': groupType.value,
        'privacy': privacy.value,
        'target_amount': targetAmount,
        'receiving_momo_code': paymentRecipient,
        'momo_route_type': _serializeRecipientType(paymentRecipientType),
        'deadline': deadline?.toIso8601String(),
        'is_recurring': isRecurring,
      };

  @override
  List<Object?> get props => [id, creatorId, name, currentTotal, isClosed];
}

class GroupMessage extends Equatable {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.alias,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String? alias;
  final String content;
  final DateTime createdAt;

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      alias: json['alias'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'group_id': groupId,
        'content': content,
      };

  @override
  List<Object?> get props => [id, groupId, senderId, content];
}

// ─── Helpers ──────────────────────────────────────────────

jh.PaymentRecipientType? _parseRecipientType(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'phone_number' || 'phone' => jh.PaymentRecipientType.phoneNumber,
    'code' => jh.PaymentRecipientType.code,
    _ => null,
  };
}

String? _serializeRecipientType(jh.PaymentRecipientType? value) {
  return switch (value) {
    jh.PaymentRecipientType.phoneNumber => 'phone_number',
    jh.PaymentRecipientType.code => 'code',
    null => null,
  };
}
