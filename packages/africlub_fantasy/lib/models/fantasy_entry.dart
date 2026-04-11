import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'fantasy_entry.freezed.dart';
part 'fantasy_entry.g.dart';

@freezed
class FantasyEntry with _$FantasyEntry {
  const factory FantasyEntry({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'competition_id') required String competitionId,
    @JsonKey(name: 'team_name') required String teamName,
    @JsonKey(name: 'overall_points') @Default(0) int overallPoints,
    @JsonKey(name: 'overall_rank') int? overallRank,
    @JsonKey(name: 'total_transfers') @Default(0) int totalTransfers,
    @JsonKey(name: 'chips_used')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> chipsUsed,
    @JsonKey(name: 'bank_balance') @Default(0) int bankBalance,
    @JsonKey(name: 'team_value') @Default(0) int teamValue,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _FantasyEntry;

  factory FantasyEntry.fromJson(Map<String, dynamic> json) =>
      _$FantasyEntryFromJson(json);
}

extension FantasyEntryX on FantasyEntry {
  String get bankDisplay => '£${(bankBalance / 10).toStringAsFixed(1)}M';
  String get teamValueDisplay => '£${(teamValue / 10).toStringAsFixed(1)}M';
  String get rankDisplay => overallRank != null
      ? '#${NumberFormat.decimalPattern().format(overallRank)}'
      : 'Unranked';
  bool get hasUsedWildcard =>
      chipsUsed.any((chip) => chip['chip'] == 'wildcard');
}
