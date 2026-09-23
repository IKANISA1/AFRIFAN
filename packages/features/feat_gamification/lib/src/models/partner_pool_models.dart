enum PartnerPoolOutcome { homeWin, draw, awayWin, unknown }

extension PartnerPoolOutcomeLabels on PartnerPoolOutcome {
  String get rpcValue {
    return switch (this) {
      PartnerPoolOutcome.homeWin => 'home_win',
      PartnerPoolOutcome.draw => 'draw',
      PartnerPoolOutcome.awayWin => 'away_win',
      PartnerPoolOutcome.unknown => 'unknown',
    };
  }

  String get label {
    return switch (this) {
      PartnerPoolOutcome.homeWin => 'Home win',
      PartnerPoolOutcome.draw => 'Draw',
      PartnerPoolOutcome.awayWin => 'Away win',
      PartnerPoolOutcome.unknown => 'Unknown',
    };
  }

  String get shortLabel {
    return switch (this) {
      PartnerPoolOutcome.homeWin => 'Home',
      PartnerPoolOutcome.draw => 'Draw',
      PartnerPoolOutcome.awayWin => 'Away',
      PartnerPoolOutcome.unknown => 'Unknown',
    };
  }
}

class PartnerPoolEntry {
  const PartnerPoolEntry({
    required this.id,
    required this.selectedOutcome,
    required this.eligibilityStatus,
    required this.status,
    required this.payoutFet,
    required this.refundedFet,
    this.joinedAt,
  });

  final String id;
  final PartnerPoolOutcome selectedOutcome;
  final String eligibilityStatus;
  final String status;
  final int payoutFet;
  final int refundedFet;
  final DateTime? joinedAt;

  factory PartnerPoolEntry.fromJson(Map<String, dynamic> json) {
    return PartnerPoolEntry(
      id: json['id']?.toString() ?? '',
      selectedOutcome: _parseOutcome(json['selected_outcome']?.toString()),
      eligibilityStatus: json['eligibility_status']?.toString() ?? 'pending',
      status: json['status']?.toString() ?? 'active',
      payoutFet: (json['payout_fet'] as num?)?.toInt() ?? 0,
      refundedFet: (json['refunded_fet'] as num?)?.toInt() ?? 0,
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? ''),
    );
  }
}

class PartnerPoolSettlement {
  const PartnerPoolSettlement({
    required this.officialOutcome,
    required this.logicalWinners,
    required this.eligibleWinners,
    required this.ineligibleWinners,
    required this.totalPaidFet,
    required this.totalRefundedFet,
    required this.unawardedPartnerFet,
    required this.settlementMode,
    this.settledAt,
  });

  final PartnerPoolOutcome officialOutcome;
  final int logicalWinners;
  final int eligibleWinners;
  final int ineligibleWinners;
  final int totalPaidFet;
  final int totalRefundedFet;
  final int unawardedPartnerFet;
  final String settlementMode;
  final DateTime? settledAt;

  factory PartnerPoolSettlement.fromJson(Map<String, dynamic> json) {
    return PartnerPoolSettlement(
      officialOutcome: _parseOutcome(json['official_outcome']?.toString()),
      logicalWinners: (json['logical_winners'] as num?)?.toInt() ?? 0,
      eligibleWinners: (json['eligible_winners'] as num?)?.toInt() ?? 0,
      ineligibleWinners: (json['ineligible_winners'] as num?)?.toInt() ?? 0,
      totalPaidFet: (json['total_paid_fet'] as num?)?.toInt() ?? 0,
      totalRefundedFet: (json['total_refunded_fet'] as num?)?.toInt() ?? 0,
      unawardedPartnerFet:
          (json['unawarded_partner_fet'] as num?)?.toInt() ?? 0,
      settlementMode: json['settlement_mode']?.toString() ?? '',
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? ''),
    );
  }
}

class PartnerPredictionPool {
  const PartnerPredictionPool({
    required this.id,
    required this.clubId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerSlug,
    required this.fixtureId,
    required this.title,
    required this.partnerStakeFet,
    required this.fanEntryFet,
    required this.eligibilityMode,
    required this.status,
    required this.lockAt,
    required this.totalEntries,
    required this.totalFanEntryFet,
    this.initiativeId,
    this.viewerEntry,
    this.settlement,
  });

  final String id;
  final int clubId;
  final String partnerId;
  final String partnerName;
  final String partnerSlug;
  final String? initiativeId;
  final String fixtureId;
  final String title;
  final int partnerStakeFet;
  final int fanEntryFet;
  final String eligibilityMode;
  final String status;
  final DateTime? lockAt;
  final int totalEntries;
  final int totalFanEntryFet;
  final PartnerPoolEntry? viewerEntry;
  final PartnerPoolSettlement? settlement;

  bool get hasJoined => viewerEntry != null;
  bool get isOpen => status == 'open';

  String get eligibilityLabel {
    return switch (eligibilityMode) {
      'partner_earn_required' => 'Partner earn required',
      'initiative_earn_required' => 'Promotion earn required',
      _ => 'Open to all fans',
    };
  }

  factory PartnerPredictionPool.fromJson(Map<String, dynamic> json) {
    final rawEntry = json['viewer_entry'];
    final rawSettlement = json['settlement'];

    return PartnerPredictionPool(
      id: json['id']?.toString() ?? '',
      clubId: (json['club_id'] as num?)?.toInt() ?? 0,
      partnerId: json['partner_id']?.toString() ?? '',
      partnerName: json['partner_name']?.toString() ?? 'Partner',
      partnerSlug: json['partner_slug']?.toString() ?? '',
      initiativeId: _nullableString(json['initiative_id']),
      fixtureId: json['fixture_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Partner WDW pool',
      partnerStakeFet: (json['partner_stake_fet'] as num?)?.toInt() ?? 0,
      fanEntryFet: (json['fan_entry_fet'] as num?)?.toInt() ?? 0,
      eligibilityMode: json['eligibility_mode']?.toString() ?? 'open_to_all',
      status: json['status']?.toString() ?? 'open',
      lockAt: DateTime.tryParse(json['lock_at']?.toString() ?? ''),
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      totalFanEntryFet: (json['total_fan_entry_fet'] as num?)?.toInt() ?? 0,
      viewerEntry: rawEntry is Map<String, dynamic>
          ? PartnerPoolEntry.fromJson(rawEntry)
          : rawEntry is Map
          ? PartnerPoolEntry.fromJson(Map<String, dynamic>.from(rawEntry))
          : null,
      settlement: rawSettlement is Map<String, dynamic>
          ? PartnerPoolSettlement.fromJson(rawSettlement)
          : rawSettlement is Map
          ? PartnerPoolSettlement.fromJson(
              Map<String, dynamic>.from(rawSettlement),
            )
          : null,
    );
  }
}

class PartnerPoolMutationResult {
  const PartnerPoolMutationResult({required this.status, this.pool});

  final String status;
  final PartnerPredictionPool? pool;

  factory PartnerPoolMutationResult.fromJson(Map<String, dynamic> json) {
    final explicitStatus =
        json['mutation_status']?.toString() ??
        json['result_status']?.toString();
    return PartnerPoolMutationResult(
      status: explicitStatus ?? (json.containsKey('id') ? 'success' : 'error'),
      pool: PartnerPredictionPool.fromJson(json),
    );
  }
}

PartnerPoolOutcome _parseOutcome(String? value) {
  return switch (value) {
    'home_win' => PartnerPoolOutcome.homeWin,
    'draw' => PartnerPoolOutcome.draw,
    'away_win' => PartnerPoolOutcome.awayWin,
    _ => PartnerPoolOutcome.unknown,
  };
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
