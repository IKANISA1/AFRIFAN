import 'package:core_utils/core_utils.dart' as jh;
import 'package:equatable/equatable.dart';

/// A contribution Group / funding group.
class ContributionGroup extends Equatable {
  const ContributionGroup({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    this.groupType = jh.ContributionGroupType.community,
    this.targetAmount = 0,
    this.currentTotal = 0,
    this.paymentRecipient,
    this.paymentRecipientType,
    this.deadline,
    this.isRecurring = false,
    this.isClosed = false,
    this.memberCount = 0,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final jh.ContributionGroupType groupType;
  final int targetAmount;
  final int currentTotal;
  final String? paymentRecipient;
  final jh.PaymentRecipientType? paymentRecipientType;
  final DateTime? deadline;
  final bool isRecurring;
  final bool isClosed;
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
      creatorId: jh.asStringOrNull(json['creator_id']) ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      groupType: jh.ContributionGroupTypeX.fromValue(
        json['group_type'] as String?,
      ),
      targetAmount: jh.asInt(json['target_amount']),
      currentTotal: jh.asInt(json['current_total']),
      paymentRecipient:
          jh.asStringOrNull(json['momo_recipient_code']) ??
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
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'name': name,
    'description': description,
    'group_type': groupType.value,
    'target_amount': targetAmount,
    'receiving_momo_code': paymentRecipient,
    'momo_route_type': _serializeRecipientType(paymentRecipientType),
    'deadline': deadline?.toIso8601String(),
    'is_recurring': isRecurring,
  };

  @override
  List<Object?> get props => [id, creatorId, name, currentTotal, isClosed];
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
