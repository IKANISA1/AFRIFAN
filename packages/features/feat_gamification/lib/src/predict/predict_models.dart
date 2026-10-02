enum PredictSelection { home, draw, away }

class PredictFixture {
  const PredictFixture({
    required this.id,
    required this.poolId,
    required this.competitionId,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeCrest,
    required this.awayCrest,
    required this.kickoffAt,
    required this.locksAt,
    required this.stakeFet,
    this.competitionLogo,
    this.round,
    this.status = 'open',
    this.selection,
    this.outcome,
    this.payoutFet = 0,
    this.economicsVersion = 'legacy_paid_v1',
    this.scorePoints = 0,
  });

  final String id;
  final String poolId;
  final String competitionId;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final String homeCrest;
  final String awayCrest;
  final String? competitionLogo;
  final String? round;
  final DateTime kickoffAt;
  final DateTime locksAt;
  final int stakeFet;
  final String status;
  final PredictSelection? selection;
  final String? outcome;
  final int payoutFet;
  final String economicsVersion;
  final int scorePoints;

  bool get isFreeEntry => economicsVersion == 'free_v1' && stakeFet == 0;

  bool isOpen(DateTime now) =>
      status == 'open' && kickoffAt.isAfter(now) && locksAt.isAfter(now);

  String selectionName(PredictSelection value, String drawLabel) =>
      switch (value) {
        PredictSelection.home => homeTeam,
        PredictSelection.draw => drawLabel,
        PredictSelection.away => awayTeam,
      };

  factory PredictFixture.fromJson(Map<String, dynamic> row) => PredictFixture(
    id: _text(row, 'id'),
    poolId: _text(row, 'pool_id'),
    competitionId: _text(row, 'competition_id'),
    competition: _text(row, 'competition'),
    homeTeam: _text(row, 'home_team'),
    awayTeam: _text(row, 'away_team'),
    homeCrest: _imageUrl(row, 'home_crest'),
    awayCrest: _imageUrl(row, 'away_crest'),
    competitionLogo: _optionalImageUrl(row['competition_logo']),
    round: row['round'] as String?,
    kickoffAt: DateTime.parse(_text(row, 'kickoff_at')),
    locksAt: DateTime.parse(_text(row, 'locks_at')),
    stakeFet: _entryFet(row),
    status: _text(row, 'status'),
    selection: row['selection'] == null
        ? null
        : PredictSelection.values.byName(row['selection'] as String),
    outcome: row['outcome'] as String?,
    payoutFet: _payoutFet(row),
    economicsVersion: _economicsVersion(row),
    scorePoints: _scorePoints(row),
  );
}

String _economicsVersion(Map<String, dynamic> row) {
  // Missing versions remain historical read-only data, never free entries.
  final version = row['economics_version'] ?? 'legacy_paid_v1';
  if (version != 'free_v1' && version != 'legacy_paid_v1') {
    throw const FormatException('Invalid Predict economics version');
  }
  return version as String;
}

int _entryFet(Map<String, dynamic> row) {
  final amount = _integer(row, 'stake_fet');
  if ((_economicsVersion(row) == 'free_v1' && amount != 0) ||
      (_economicsVersion(row) == 'legacy_paid_v1' && amount <= 0)) {
    throw const FormatException('Invalid Predict entry policy');
  }
  return amount;
}

int _payoutFet(Map<String, dynamic> row) {
  final value = row['payout_fet'] == null ? 0 : _integer(row, 'payout_fet');
  if (_economicsVersion(row) == 'free_v1' && value != 0) {
    throw const FormatException('Free Predict cannot credit FET');
  }
  return value;
}

int _scorePoints(Map<String, dynamic> row) {
  final value = row['score_points'] == null ? 0 : _integer(row, 'score_points');
  if (_economicsVersion(row) == 'free_v1' &&
      value != (row['outcome'] == 'won' ? 1 : 0)) {
    throw const FormatException('Invalid Predict accuracy points');
  }
  return value;
}

class PredictLedgerEntry {
  const PredictLedgerEntry({
    required this.id,
    required this.createdAt,
    required this.deltaFet,
    required this.type,
  });

  final String id;
  final DateTime createdAt;
  final int deltaFet;
  final String type;

  factory PredictLedgerEntry.fromJson(Map<String, dynamic> row) =>
      PredictLedgerEntry(
        id: _text(row, 'id'),
        createdAt: DateTime.parse(_text(row, 'created_at')),
        deltaFet: _integer(row, 'delta_fet', minimum: -2147483647),
        type: _text(row, 'entry_type'),
      );
}

class PredictDashboard {
  const PredictDashboard({
    this.enabled = false,
    this.memberSession = false,
    this.balanceFet,
    this.fixtures = const [],
    this.history = const [],
    this.ledger = const [],
  });

  final bool enabled;
  final bool memberSession;
  final int? balanceFet;
  final List<PredictFixture> fixtures;
  final List<PredictFixture> history;
  final List<PredictLedgerEntry> ledger;

  factory PredictDashboard.fromJson(Map<String, dynamic> row) {
    if (row['enabled'] is! bool || row['member_session'] is! bool) {
      throw const FormatException('Invalid Predict response');
    }
    return PredictDashboard(
      enabled: row['enabled'] as bool,
      memberSession: row['member_session'] as bool,
      balanceFet: row['wallet'] == null
          ? null
          : _integer(
              Map<String, dynamic>.from(row['wallet'] as Map),
              'balance_fet',
            ),
      fixtures: _rows(
        row,
        'fixtures',
      ).map(PredictFixture.fromJson).toList(growable: false),
      history: _rows(
        row,
        'history',
      ).map(PredictFixture.fromJson).toList(growable: false),
      ledger: _rows(
        row,
        'ledger',
      ).map(PredictLedgerEntry.fromJson).toList(growable: false),
    );
  }

  PredictDashboard withConfirmed(PredictFixture fixture, int? balance) =>
      PredictDashboard(
        enabled: enabled,
        memberSession: memberSession,
        balanceFet: balance ?? balanceFet,
        fixtures: [
          for (final row in fixtures) row.id == fixture.id ? fixture : row,
        ],
        history: [fixture, ...history.where((row) => row.id != fixture.id)],
        ledger: ledger,
      );
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> row, String key) =>
    (row[key] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);

String _text(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty || value.length > 2000) {
    throw FormatException('Invalid Predict $key');
  }
  return value.trim();
}

int _integer(Map<String, dynamic> row, String key, {int minimum = 0}) {
  final value = row[key];
  if (value is! num ||
      value != value.toInt() ||
      value < minimum ||
      value > 2147483647) {
    throw FormatException('Invalid Predict $key');
  }
  return value.toInt();
}

String _imageUrl(Map<String, dynamic> row, String key) =>
    _optionalImageUrl(row[key]) ??
    (throw FormatException('Invalid Predict $key'));

String? _optionalImageUrl(Object? value) {
  if (value is! String || value.length > 2000) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          !uri.hasPort &&
          uri.userInfo.isEmpty
      ? value
      : null;
}
