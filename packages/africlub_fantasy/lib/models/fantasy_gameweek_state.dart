class FantasyGameweekState {
  const FantasyGameweekState({
    required this.entryId,
    required this.gameweekId,
    required this.freeTransfersAvailable,
    required this.freeTransfersRemaining,
    required this.transfersMade,
    required this.transferCost,
    required this.bankBalance,
    required this.teamValue,
    this.chipPlayed,
  });

  final String entryId;
  final String gameweekId;
  final int freeTransfersAvailable;
  final int freeTransfersRemaining;
  final int transfersMade;
  final int transferCost;
  final int bankBalance;
  final int teamValue;
  final String? chipPlayed;

  bool get hasUnlimitedTransfers =>
      chipPlayed == 'wildcard' || chipPlayed == 'free_hit';

  factory FantasyGameweekState.fromJson(Map<String, dynamic> json) {
    return FantasyGameweekState(
      entryId: (json['entry_id'] ?? '').toString(),
      gameweekId: (json['gameweek_id'] ?? '').toString(),
      freeTransfersAvailable:
          (json['free_transfers_available'] as num?)?.toInt() ?? 0,
      freeTransfersRemaining:
          (json['free_transfers_remaining'] as num?)?.toInt() ?? 0,
      transfersMade: (json['transfers_made'] as num?)?.toInt() ?? 0,
      transferCost: (json['transfer_cost'] as num?)?.toInt() ?? 0,
      chipPlayed: json['chip_played']?.toString(),
      bankBalance: (json['bank_balance'] as num?)?.toInt() ?? 0,
      teamValue: (json['team_value'] as num?)?.toInt() ?? 0,
    );
  }
}
