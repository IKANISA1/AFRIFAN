import 'package:core_utils/core_utils.dart' as jh;

import 'biopay_profile.dart';

/// Result of a face match operation.
class BioPayMatchResult {
  const BioPayMatchResult({
    required this.match,
    required this.score,
    this.profile,
    this.cached = false,
    this.matchReceipt,
    this.matchReceiptExpiresAt,
  });

  final bool match;
  final double score;
  final BioPayProfile? profile;
  final bool cached;
  final String? matchReceipt;
  final DateTime? matchReceiptExpiresAt;

  factory BioPayMatchResult.fromApiResponse(Map<String, dynamic> json) {
    final match = jh.asBool(json['match']);
    final score = jh.asDouble(json['score']);
    if (!match) {
      return BioPayMatchResult(match: false, score: score);
    }

    return BioPayMatchResult(
      match: true,
      score: score,
      matchReceipt: jh.asStringOrNull(json['match_receipt']),
      matchReceiptExpiresAt: jh.parseDateTime(json['match_receipt_expires_at']),
      profile: BioPayProfile.fromJson(<String, dynamic>{
        'id': json['profile_id'],
        'public_id': json['public_id'],
        'user_id': json['user_id'],
        'display_name': json['display_name'],
        'route_type': json['route_type'],
        'recipient_value': json['recipient_value'],
        'country_code': json['country_code'],
        'active': true,
        'consent_version': json['consent_version'] ?? 'BioPay-v1',
        'consent_at': json['consent_at'],
        'created_at': json['created_at'],
        'updated_at': json['updated_at'],
      }),
    );
  }

  factory BioPayMatchResult.fromCacheJson(Map<String, dynamic> json) {
    return BioPayMatchResult(
      match: jh.asBool(json['match']),
      score: jh.asDouble(json['score']),
      cached: jh.asBool(json['cached']),
      matchReceipt: jh.asStringOrNull(json['match_receipt']),
      matchReceiptExpiresAt: jh.parseDateTime(json['match_receipt_expires_at']),
      profile: jh.asMapOrNull(json['profile']) == null
          ? null
          : BioPayProfile.fromJson(jh.asMap(json['profile'])),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'match': match,
      'score': score,
      'cached': cached,
      'match_receipt': matchReceipt,
      'match_receipt_expires_at': matchReceiptExpiresAt?.toIso8601String(),
      'profile': profile?.toJson(),
    };
  }

  BioPayMatchResult copyWith({bool? cached}) {
    return BioPayMatchResult(
      match: match,
      score: score,
      profile: profile,
      cached: cached ?? this.cached,
      matchReceipt: matchReceipt,
      matchReceiptExpiresAt: matchReceiptExpiresAt,
    );
  }
}
