enum FantasyCompetitionMode { seasonLong, tournament }

FantasyCompetitionMode fantasyCompetitionModeFromRaw(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'tournament':
      return FantasyCompetitionMode.tournament;
    default:
      return FantasyCompetitionMode.seasonLong;
  }
}

enum FantasyCompetitionStatus { planned, preview, playable, archived }

FantasyCompetitionStatus fantasyCompetitionStatusFromRaw(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'active':
    case 'live':
    case 'playable':
      return FantasyCompetitionStatus.playable;
    case 'finished':
    case 'archived':
      return FantasyCompetitionStatus.archived;
    case 'draft':
    case 'preview':
      return FantasyCompetitionStatus.preview;
    default:
      return FantasyCompetitionStatus.planned;
  }
}

enum FantasyPlayerPosition { gk, def, mid, fwd }

FantasyPlayerPosition fantasyPlayerPositionFromRaw(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case 'GK':
      return FantasyPlayerPosition.gk;
    case 'DEF':
      return FantasyPlayerPosition.def;
    case 'MID':
      return FantasyPlayerPosition.mid;
    default:
      return FantasyPlayerPosition.fwd;
  }
}

extension FantasyPlayerPositionX on FantasyPlayerPosition {
  String get code => switch (this) {
    FantasyPlayerPosition.gk => 'GK',
    FantasyPlayerPosition.def => 'DEF',
    FantasyPlayerPosition.mid => 'MID',
    FantasyPlayerPosition.fwd => 'FWD',
  };

  String get label => switch (this) {
    FantasyPlayerPosition.gk => 'Goalkeeper',
    FantasyPlayerPosition.def => 'Defender',
    FantasyPlayerPosition.mid => 'Midfielder',
    FantasyPlayerPosition.fwd => 'Forward',
  };
}

class FantasyCompetitionSummary {
  const FantasyCompetitionSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.season,
    required this.description,
    required this.mode,
    required this.status,
    this.provider,
    this.promoTitle,
    this.promoBody,
    this.entryWindowOpensAt,
    this.entryWindowClosesAt,
    this.isVisible = true,
    this.isFeatured = false,
    this.isPlayable = false,
    this.entryWindowOpen = false,
    this.hasEntry = false,
    this.activeEntries = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String season;
  final String description;
  final FantasyCompetitionMode mode;
  final FantasyCompetitionStatus status;
  final String? provider;
  final String? promoTitle;
  final String? promoBody;
  final DateTime? entryWindowOpensAt;
  final DateTime? entryWindowClosesAt;
  final bool isVisible;
  final bool isFeatured;
  final bool isPlayable;
  final bool entryWindowOpen;
  final bool hasEntry;
  final int activeEntries;

  String get modeLabel => switch (mode) {
    FantasyCompetitionMode.seasonLong => 'SEASON',
    FantasyCompetitionMode.tournament => 'TOURNAMENT',
  };

  String get statusLabel => switch (status) {
    FantasyCompetitionStatus.playable => isPlayable ? 'LIVE' : 'READY',
    FantasyCompetitionStatus.preview => 'PREVIEW',
    FantasyCompetitionStatus.archived => 'ARCHIVED',
    FantasyCompetitionStatus.planned => 'PLANNED',
  };

  String get ctaLabel {
    if (hasEntry) {
      return 'Continue';
    }
    if (isPlayable && entryWindowOpen) {
      return 'Join now';
    }
    if (status == FantasyCompetitionStatus.preview) {
      return 'Preview';
    }
    return 'Explore';
  }

  String get heroTitle =>
      promoTitle?.trim().isNotEmpty == true ? promoTitle! : name;

  String get heroBody =>
      promoBody?.trim().isNotEmpty == true ? promoBody! : description;
}

class FantasyLeaderboardRow {
  const FantasyLeaderboardRow({
    required this.rank,
    required this.teamName,
    required this.points,
    this.isCurrentUser = false,
  });

  final int rank;
  final String teamName;
  final int points;
  final bool isCurrentUser;
}

class FantasyGameweekSummary {
  const FantasyGameweekSummary({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
    required this.deadlineAt,
  });

  final String id;
  final int number;
  final String name;
  final String status;
  final DateTime? deadlineAt;

  bool get isLocked =>
      deadlineAt != null && deadlineAt!.isBefore(DateTime.now());
}

class FantasyEntryContext {
  const FantasyEntryContext({
    required this.competitionId,
    required this.competitionSlug,
    required this.competitionName,
    required this.competitionMode,
    required this.competitionStatus,
    required this.squadConfig,
    required this.transferConfig,
    this.gameweek,
    this.entryId,
    this.teamName,
    this.bankBalance = 0,
    this.teamValue = 0,
    this.overallPoints = 0,
    this.overallRank,
  });

  final String competitionId;
  final String competitionSlug;
  final String competitionName;
  final FantasyCompetitionMode competitionMode;
  final FantasyCompetitionStatus competitionStatus;
  final Map<String, dynamic> squadConfig;
  final Map<String, dynamic> transferConfig;
  final FantasyGameweekSummary? gameweek;
  final String? entryId;
  final String? teamName;
  final int bankBalance;
  final int teamValue;
  final int overallPoints;
  final int? overallRank;

  int get budget => (squadConfig['budget'] as num?)?.toInt() ?? 1000;

  int get maxPerClub => (squadConfig['max_per_club'] as num?)?.toInt() ?? 3;

  bool get hasEntry => entryId?.trim().isNotEmpty == true;
}

class FantasyPlayerPoolItem {
  const FantasyPlayerPoolItem({
    required this.playerId,
    required this.name,
    required this.shortName,
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.teamShort,
    required this.price,
    this.photoUrl,
    this.teamLogoUrl,
    this.nationality,
    this.priceChange = 0,
    this.ownershipPercent = 0,
  });

  final int playerId;
  final String name;
  final String shortName;
  final FantasyPlayerPosition position;
  final int teamId;
  final String teamName;
  final String teamShort;
  final int price;
  final String? photoUrl;
  final String? teamLogoUrl;
  final String? nationality;
  final int priceChange;
  final double ownershipPercent;

  String get displayName =>
      shortName.trim().isNotEmpty ? shortName.trim() : name.trim();
}

class FantasySquadSelection {
  const FantasySquadSelection({
    required this.playerId,
    required this.name,
    required this.shortName,
    required this.position,
    required this.teamName,
    required this.teamShort,
    required this.purchasePrice,
    required this.isStarter,
    required this.isCaptain,
    required this.isViceCaptain,
    required this.multiplier,
    this.selectionId,
    this.gameweekId,
    this.photoUrl,
    this.teamLogoUrl,
    this.benchOrder,
  });

  final String? selectionId;
  final String? gameweekId;
  final int playerId;
  final String name;
  final String shortName;
  final FantasyPlayerPosition position;
  final String teamName;
  final String teamShort;
  final int purchasePrice;
  final bool isStarter;
  final int? benchOrder;
  final bool isCaptain;
  final bool isViceCaptain;
  final int multiplier;
  final String? photoUrl;
  final String? teamLogoUrl;

  String get displayName =>
      shortName.trim().isNotEmpty ? shortName.trim() : name.trim();

  FantasySquadSelection copyWith({
    String? selectionId,
    String? gameweekId,
    int? playerId,
    String? name,
    String? shortName,
    FantasyPlayerPosition? position,
    String? teamName,
    String? teamShort,
    int? purchasePrice,
    bool? isStarter,
    Object? benchOrder = _sentinel,
    bool? isCaptain,
    bool? isViceCaptain,
    int? multiplier,
    Object? photoUrl = _sentinel,
    Object? teamLogoUrl = _sentinel,
  }) {
    return FantasySquadSelection(
      selectionId: selectionId ?? this.selectionId,
      gameweekId: gameweekId ?? this.gameweekId,
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      position: position ?? this.position,
      teamName: teamName ?? this.teamName,
      teamShort: teamShort ?? this.teamShort,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      isStarter: isStarter ?? this.isStarter,
      benchOrder: benchOrder == _sentinel
          ? this.benchOrder
          : benchOrder as int?,
      isCaptain: isCaptain ?? this.isCaptain,
      isViceCaptain: isViceCaptain ?? this.isViceCaptain,
      multiplier: multiplier ?? this.multiplier,
      photoUrl: photoUrl == _sentinel ? this.photoUrl : photoUrl as String?,
      teamLogoUrl: teamLogoUrl == _sentinel
          ? this.teamLogoUrl
          : teamLogoUrl as String?,
    );
  }

  Map<String, dynamic> toRpcPayload() {
    return {
      'player_id': playerId,
      'position': position.code,
      'is_starter': isStarter,
      'bench_order': benchOrder,
      'is_captain': isCaptain,
      'is_vice_captain': isViceCaptain,
      'purchase_price': purchasePrice,
      'multiplier': multiplier,
    };
  }
}

class FantasySquadBuilderData {
  const FantasySquadBuilderData({
    required this.context,
    required this.playerPool,
    required this.squad,
  });

  final FantasyEntryContext context;
  final List<FantasyPlayerPoolItem> playerPool;
  final List<FantasySquadSelection> squad;
}

const Object _sentinel = Object();
