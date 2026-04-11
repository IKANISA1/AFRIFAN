import 'package:core_utils/core_utils.dart' as jh;

/// Wallet ledger entry — a single financial transaction.
///
/// White-label: currency is dynamic (not hardcoded to RWF).
class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.entryType,
    required this.ledgerStatus,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.txCategory,
    required this.cashflowBucket,
    required this.label,
    this.counterpartyName,
    this.reference,
    this.description,
    this.providerTxId,
    this.payerName,
    this.payerPhone,
  });

  final String id;
  final String entryType;
  final String ledgerStatus;
  final int amount;
  final String currency;
  final DateTime occurredAt;
  final String txCategory;
  final String cashflowBucket;
  final String label;
  final String? counterpartyName;
  final String? reference;
  final String? description;
  final String? providerTxId;
  final String? payerName;
  final String? payerPhone;

  bool get isCredit => entryType == 'credit';
  bool get isDebit => entryType == 'debit';

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    final parsedSms =
        json['momo_sms_parsed'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return WalletLedgerEntry(
      id: jh.asStringOrNull(json['id']) ?? '',
      entryType: jh.asStringOrNull(json['entry_type']) ?? 'debit',
      ledgerStatus: jh.asStringOrNull(json['ledger_status']) ?? 'draft',
      amount: jh.asInt(json['amount']),
      currency:
          jh.asStringOrNull(json['currency']) ??
          jh.asStringOrNull(parsedSms['currency']) ??
          '',
      occurredAt:
          jh.parseDateTime(json['tx_datetime']) ??
          jh.parseDateTime(json['created_at']) ??
          DateTime.now(),
      txCategory: jh.asStringOrNull(json['tx_category']) ?? 'uncategorized',
      cashflowBucket: jh.asStringOrNull(json['cashflow_bucket']) ?? 'unknown',
      label:
          jh.asStringOrNull(json['statement_label']) ??
          jh.asStringOrNull(json['description']) ??
          _titleize(
            jh.asStringOrNull(json['tx_category']) ??
                jh.asStringOrNull(json['entry_type']),
          ),
      counterpartyName: jh.asStringOrNull(json['counterparty_name']),
      reference: jh.asStringOrNull(json['external_reference']),
      description: jh.asStringOrNull(json['description']),
      providerTxId: jh.asStringOrNull(parsedSms['momo_tx_id']),
      payerName: jh.asStringOrNull(parsedSms['payer_name']),
      payerPhone:
          jh.asStringOrNull(parsedSms['payer_number_full']) ??
          jh.asStringOrNull(parsedSms['payer_number_last3']),
    );
  }
}

/// Payee payment ledger entry — for admin/partner receivables.
class PayeeLedgerEntry {
  const PayeeLedgerEntry({
    required this.ledgerId,
    required this.payerUserId,
    required this.payerName,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.txCategory,
    required this.cashflowBucket,
    required this.label,
    required this.targetTable,
    this.payerPhone,
    this.reference,
    this.counterpartyName,
    this.targetRecordId,
  });

  final String ledgerId;
  final String payerUserId;
  final String payerName;
  final String? payerPhone;
  final int amount;
  final String currency;
  final DateTime occurredAt;
  final String? reference;
  final String txCategory;
  final String cashflowBucket;
  final String label;
  final String? counterpartyName;
  final String targetTable;
  final String? targetRecordId;

  factory PayeeLedgerEntry.fromJson(Map<String, dynamic> json) {
    return PayeeLedgerEntry(
      ledgerId: jh.asStringOrNull(json['ledger_id']) ?? '',
      payerUserId: jh.asStringOrNull(json['payer_user_id']) ?? '',
      payerName: jh.asStringOrNull(json['payer_name']) ?? 'Member',
      payerPhone: jh.asStringOrNull(json['payer_phone']),
      amount: jh.asInt(json['amount']),
      currency: jh.asStringOrNull(json['currency']) ?? '',
      occurredAt:
          jh.parseDateTime(json['tx_datetime']) ??
          jh.parseDateTime(json['created_at']) ??
          DateTime.now(),
      reference: jh.asStringOrNull(json['external_reference']),
      txCategory: jh.asStringOrNull(json['tx_category']) ?? 'uncategorized',
      cashflowBucket: jh.asStringOrNull(json['cashflow_bucket']) ?? 'unknown',
      label:
          jh.asStringOrNull(json['statement_label']) ??
          _titleize(jh.asStringOrNull(json['tx_category']) ?? 'payment'),
      counterpartyName: jh.asStringOrNull(json['counterparty_name']),
      targetTable: jh.asStringOrNull(json['target_table']) ?? '',
      targetRecordId: jh.asStringOrNull(json['target_record_id']),
    );
  }
}

/// Statement query parameters.
class LedgerQuery {
  const LedgerQuery({
    this.startDate,
    this.endDate,
    this.limit = 1000,
    this.offset = 0,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;
  final int offset;

  DateTime? get startAtUtc {
    final d = startDate;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day).toUtc();
  }

  DateTime? get endBeforeUtc {
    final d = endDate;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day + 1).toUtc();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerQuery &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.limit == limit &&
          other.offset == offset;

  @override
  int get hashCode => Object.hash(startDate, endDate, limit, offset);
}

/// Paginated statement result.
class LedgerPage<T> {
  const LedgerPage({this.entries = const [], this.totalCount = 0});

  final List<T> entries;
  final int totalCount;

  bool hasMore({required int offset}) => offset + entries.length < totalCount;
}

// ─── Helpers ────────────────────────────────────────────────

String _titleize(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) return 'Wallet transaction';
  return normalized
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
