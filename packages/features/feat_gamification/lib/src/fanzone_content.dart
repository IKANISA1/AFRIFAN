import 'package:flutter/material.dart';

class FanzoneFlow {
  const FanzoneFlow({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  final String code;
  final String title;
  final String subtitle;
  final List<FanzoneFlowStep> steps;
}

class FanzoneFlowStep {
  const FanzoneFlowStep({
    required this.index,
    required this.title,
    required this.detail,
    this.cues = const <String>[],
  });

  final int index;
  final String title;
  final String detail;
  final List<String> cues;
}

class PredictionMarketFamily {
  const PredictionMarketFamily({
    required this.title,
    required this.countLabel,
    required this.items,
  });

  final String title;
  final String countLabel;
  final List<PredictionMarketItem> items;
}

class PredictionMarketItem {
  const PredictionMarketItem({
    required this.name,
    required this.code,
    required this.level,
  });

  final String name;
  final String code;
  final String level;
}

class LeagueCoverageGroup {
  const LeagueCoverageGroup({required this.title, required this.items});

  final String title;
  final List<LeagueCoverageItem> items;
}

class LeagueCoverageItem {
  const LeagueCoverageItem({required this.name, required this.tier, this.note});

  final String name;
  final String tier;
  final String? note;
}

class FetEarnAction {
  const FetEarnAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.reward,
  });

  final IconData icon;
  final String title;
  final String description;
  final String reward;
}

class FetRewardOption {
  const FetRewardOption({
    required this.reward,
    required this.cost,
    required this.category,
    required this.notes,
  });

  final String reward;
  final String cost;
  final String category;
  final String notes;
}

class FanzoneScreenZone {
  const FanzoneScreenZone({
    required this.zone,
    required this.title,
    required this.screens,
  });

  final String zone;
  final String title;
  final List<FanzoneScreenSpec> screens;
}

class FanzoneScreenSpec {
  const FanzoneScreenSpec({
    required this.code,
    required this.title,
    required this.subtitle,
  });

  final String code;
  final String title;
  final String subtitle;
}

class MarketOffer {
  const MarketOffer({
    required this.category,
    required this.name,
    required this.multiplierLabel,
    required this.options,
    this.liveOnly = false,
  });

  final String category;
  final String name;
  final String multiplierLabel;
  final List<MarketOption> options;
  final bool liveOnly;
}

class MarketOption {
  const MarketOption({required this.label, required this.potentialFet});

  final String label;
  final int potentialFet;
}

class PredictionSlipEntry {
  const PredictionSlipEntry({
    required this.fixture,
    required this.market,
    required this.selection,
    required this.potentialFet,
    this.note,
  });

  final String fixture;
  final String market;
  final String selection;
  final int potentialFet;
  final String? note;
}

enum PredictionRecordStatus { active, won, lost }

class PredictionRecord {
  const PredictionRecord({
    required this.fixture,
    required this.market,
    required this.selection,
    required this.status,
    required this.potentialFet,
    required this.resultLabel,
    required this.timestampLabel,
  });

  final String fixture;
  final String market;
  final String selection;
  final PredictionRecordStatus status;
  final int potentialFet;
  final String resultLabel;
  final String timestampLabel;
}

const List<FanzoneFlow> fanzoneFlows = <FanzoneFlow>[
  FanzoneFlow(
    code: 'Flow A',
    title: 'First Prediction',
    subtitle: 'Decision-ready in under 60 seconds.',
    steps: <FanzoneFlowStep>[
      FanzoneFlowStep(
        index: 1,
        title: 'App Open to Home Feed',
        detail:
            'Skeleton loaders appear instantly, the featured match lands hero-style at the top, and the live match counter is visible from cold start.',
        cues: <String>['Cold start under 2s', 'Skeleton UI'],
      ),
      FanzoneFlowStep(
        index: 2,
        title: 'Tap Match Card',
        detail:
            'A hero transition takes the supporter into match detail with expanded team banners and tabs for Predict, Stats, H2H, and Live.',
        cues: <String>['Hero animation', 'Shared element'],
      ),
      FanzoneFlowStep(
        index: 3,
        title: 'Select Market and Outcome',
        detail:
            'The default market rail shows 1X2, BTTS, and Over/Under. Choosing Home Win fills the pill and raises the prediction slip counter.',
        cues: <String>['Haptic feedback', 'Optimistic UI'],
      ),
      FanzoneFlowStep(
        index: 4,
        title: 'Confirm via Slip',
        detail:
            'The floating slip expands into a review drawer with active picks, acca mode, and a lock-in CTA that clearly states the FET upside.',
        cues: <String>['Receipt animation', 'Share CTA'],
      ),
      FanzoneFlowStep(
        index: 5,
        title: 'Settlement',
        detail:
            'A push notification confirms the outcome, then drives to a settlement screen with win state, confetti, and a FET counter increment.',
        cues: <String>['Push notification', 'Confetti', 'FET animation'],
      ),
    ],
  ),
  FanzoneFlow(
    code: 'Flow B',
    title: 'Jackpot Challenge',
    subtitle: 'Ten quick picks with live rank tracking.',
    steps: <FanzoneFlowStep>[
      FanzoneFlowStep(
        index: 1,
        title: 'Jackpot Banner to Entry',
        detail:
            'The weekly jackpot banner highlights the prize pool, countdown timer, and number of matches in the round.',
        cues: <String>['Hero banner', 'Countdown timer'],
      ),
      FanzoneFlowStep(
        index: 2,
        title: 'Ten-Match Prediction Card',
        detail:
            'Card-swipe entry keeps one fixture per surface, showing a top progress bar so the user always knows how many picks remain.',
        cues: <String>['Card swipe', 'Progress indicator'],
      ),
      FanzoneFlowStep(
        index: 3,
        title: 'Submit Entry',
        detail:
            'The review step summarizes all picks, keeps the free-entry message prominent, and confirms submission with an entry number receipt.',
        cues: <String>['Free entry', 'Entry receipt'],
      ),
      FanzoneFlowStep(
        index: 4,
        title: 'Live Tracking',
        detail:
            'The jackpot hub updates fixture states in real time and compares the supporter rank against the broader field.',
        cues: <String>['Live updates', 'Rank tracker'],
      ),
      FanzoneFlowStep(
        index: 5,
        title: 'Final Settlement',
        detail:
            'The final result highlights score, final rank, payout, and a social share moment for the supporter.',
        cues: <String>['Score reveal', 'FET payout', 'Social share'],
      ),
    ],
  ),
];

const List<PredictionMarketFamily>
predictionMarketFamilies = <PredictionMarketFamily>[
  PredictionMarketFamily(
    title: 'Match Result Markets',
    countLabel: '8 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(
        name: 'Full Time Result (1X2)',
        code: 'FTR',
        level: 'Entry',
      ),
      PredictionMarketItem(name: 'Double Chance', code: 'DC', level: 'Entry'),
      PredictionMarketItem(name: 'Draw No Bet', code: 'DNB', level: 'Easy'),
      PredictionMarketItem(
        name: 'Half Time / Full Time',
        code: 'HTFT',
        level: 'Hard',
      ),
    ],
  ),
  PredictionMarketFamily(
    title: 'Goals Markets',
    countLabel: '14 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(
        name: 'Over / Under 2.5 Goals',
        code: 'O/U 2.5',
        level: 'Entry',
      ),
      PredictionMarketItem(
        name: 'Both Teams to Score',
        code: 'BTTS',
        level: 'Entry',
      ),
      PredictionMarketItem(name: 'Correct Score', code: 'CS', level: 'Hard'),
      PredictionMarketItem(name: 'Team Total Goals', code: 'TTG', level: 'Mid'),
    ],
  ),
  PredictionMarketFamily(
    title: 'Player Markets',
    countLabel: '10 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(
        name: 'Anytime Goalscorer',
        code: 'AGS',
        level: 'Easy',
      ),
      PredictionMarketItem(name: 'First Goalscorer', code: 'FGS', level: 'Mid'),
      PredictionMarketItem(name: 'Player to Assist', code: 'PAS', level: 'Mid'),
      PredictionMarketItem(
        name: 'Player Shot on Target',
        code: 'PSOT',
        level: 'Mid',
      ),
    ],
  ),
  PredictionMarketFamily(
    title: 'Corners Markets',
    countLabel: '8 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(
        name: 'Total Corners Over / Under 9.5',
        code: 'TC O/U',
        level: 'Mid',
      ),
      PredictionMarketItem(name: 'First Corner', code: 'FC', level: 'Mid'),
      PredictionMarketItem(name: 'Last Corner', code: 'LC', level: 'Hard'),
      PredictionMarketItem(
        name: 'HT Corners Over / Under 4.5',
        code: 'HTC',
        level: 'Mid',
      ),
    ],
  ),
  PredictionMarketFamily(
    title: 'Cards Markets',
    countLabel: '7 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(
        name: 'Total Cards Over / Under 2.5',
        code: 'TCard',
        level: 'Mid',
      ),
      PredictionMarketItem(name: 'Red Card in Match', code: 'RC', level: 'Mid'),
      PredictionMarketItem(
        name: 'Team Total Cards',
        code: 'TCrd',
        level: 'Mid',
      ),
      PredictionMarketItem(name: 'Cards Odd / Even', code: 'COE', level: 'Mid'),
    ],
  ),
  PredictionMarketFamily(
    title: 'Handicap Markets',
    countLabel: '5 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(name: 'European Handicap', code: 'EH', level: 'Mid'),
      PredictionMarketItem(
        name: 'Asian Handicap',
        code: 'AH',
        level: 'Advanced',
      ),
      PredictionMarketItem(name: 'Goal Line', code: 'GL', level: 'Advanced'),
    ],
  ),
  PredictionMarketFamily(
    title: 'Timing and Special Markets',
    countLabel: '8 markets',
    items: <PredictionMarketItem>[
      PredictionMarketItem(name: 'First Goal Time', code: 'FGT', level: 'Hard'),
      PredictionMarketItem(name: 'Penalty in Match', code: 'PEN', level: 'Mid'),
      PredictionMarketItem(
        name: 'Highest Scoring Half',
        code: 'HSH',
        level: 'Hard',
      ),
      PredictionMarketItem(
        name: 'Match to Go to Extra Time',
        code: 'MET',
        level: 'Hard',
      ),
    ],
  ),
];

const List<String> launchCoreMarkets = <String>[
  '1X2 Full Time',
  'Both Teams to Score',
  'Over / Under 2.5',
  'Double Chance',
  'Correct Score',
  'HT/FT Result',
  'Anytime Goalscorer',
  'Total Corners O/U',
];

const List<LeagueCoverageGroup> leagueCoverageGroups = <LeagueCoverageGroup>[
  LeagueCoverageGroup(
    title: 'International Tier 1',
    items: <LeagueCoverageItem>[
      LeagueCoverageItem(name: 'English Premier League', tier: 'Tier 1'),
      LeagueCoverageItem(name: 'Spanish La Liga', tier: 'Tier 1'),
      LeagueCoverageItem(name: 'FIFA World Cup 2026', tier: 'Tier 1'),
      LeagueCoverageItem(name: 'UEFA Champions League', tier: 'Tier 1'),
      LeagueCoverageItem(name: 'Italian Serie A', tier: 'Tier 2'),
      LeagueCoverageItem(name: 'German Bundesliga', tier: 'Tier 2'),
    ],
  ),
  LeagueCoverageGroup(
    title: 'CAF Competitions',
    items: <LeagueCoverageItem>[
      LeagueCoverageItem(name: 'CAF Champions League', tier: 'Tier 1'),
      LeagueCoverageItem(name: 'CAF Confederation Cup', tier: 'Tier 1'),
      LeagueCoverageItem(name: 'Africa Cup of Nations', tier: 'Tier 1'),
      LeagueCoverageItem(
        name: 'World Cup Qualification Africa',
        tier: 'Tier 1',
      ),
      LeagueCoverageItem(name: 'African Football League', tier: 'Tier 2'),
    ],
  ),
  LeagueCoverageGroup(
    title: 'Rwanda',
    items: <LeagueCoverageItem>[
      LeagueCoverageItem(name: 'Rwanda Premier League', tier: 'Core'),
      LeagueCoverageItem(name: 'Rwanda Cup', tier: 'Local'),
      LeagueCoverageItem(name: 'Rwanda National Super League', tier: 'Local'),
      LeagueCoverageItem(name: 'Rwanda Women\'s Premier League', tier: 'Local'),
      LeagueCoverageItem(
        name: 'Key clubs',
        tier: 'APR FC, Rayon Sports, AS Kigali, Police FC',
      ),
    ],
  ),
  LeagueCoverageGroup(
    title: 'African Domestic Leagues',
    items: <LeagueCoverageItem>[
      LeagueCoverageItem(name: 'Uganda Premier League', tier: 'Core'),
      LeagueCoverageItem(name: 'DR Congo Linafoot', tier: 'Core'),
      LeagueCoverageItem(name: 'Nigeria Premier Football League', tier: 'Core'),
      LeagueCoverageItem(name: 'South Africa DStv Premiership', tier: 'Core'),
      LeagueCoverageItem(name: 'Egypt Premier League', tier: 'Mid'),
      LeagueCoverageItem(name: 'Morocco Botola Pro', tier: 'Mid'),
      LeagueCoverageItem(name: 'Zambia Super League', tier: 'Expansion'),
    ],
  ),
];

const List<FetEarnAction> fetEarnActions = <FetEarnAction>[
  FetEarnAction(
    icon: Icons.sports_soccer_rounded,
    title: 'Correct 1X2 Prediction',
    description: 'Base earn for a correct full-time result prediction.',
    reward: '+10 FET',
  ),
  FetEarnAction(
    icon: Icons.center_focus_strong_rounded,
    title: 'Correct Score',
    description:
        'High-difficulty exact score prediction with the highest base return.',
    reward: '+50 FET',
  ),
  FetEarnAction(
    icon: Icons.local_fire_department_rounded,
    title: 'Daily Login Streak',
    description: 'Consecutive day bonus with a five-day multiplier loop.',
    reward: '+5 FET/day',
  ),
  FetEarnAction(
    icon: Icons.emoji_events_rounded,
    title: 'Jackpot Round Top 10',
    description: 'Weekly ten-match challenge with pooled rewards.',
    reward: '+500 FET',
  ),
  FetEarnAction(
    icon: Icons.people_alt_rounded,
    title: 'Refer a Friend',
    description:
        'Reward on registration and after the referred supporter makes five predictions.',
    reward: '+50 FET',
  ),
  FetEarnAction(
    icon: Icons.share_rounded,
    title: 'Share a Prediction',
    description: 'Reward for sharing prediction cards to social channels.',
    reward: '+2 FET',
  ),
];

const List<FetRewardOption> fetRewardOptions = <FetRewardOption>[
  FetRewardOption(
    reward: 'Mobile Airtime',
    cost: '500 FET',
    category: 'Utility',
    notes: 'Via MoMo API integration',
  ),
  FetRewardOption(
    reward: 'FANZONE Premium Badge',
    cost: '200 FET',
    category: 'Cosmetic',
    notes: 'Profile badge unlock',
  ),
  FetRewardOption(
    reward: 'Jackpot Extra Entry',
    cost: '100 FET',
    category: 'Gameplay',
    notes: 'Second entry in the weekly round',
  ),
  FetRewardOption(
    reward: 'Custom Avatar Frame',
    cost: '150 FET',
    category: 'Cosmetic',
    notes: 'Seasonal themed frame',
  ),
  FetRewardOption(
    reward: 'Club Fan Kit Digital Item',
    cost: '300 FET',
    category: 'Collectible',
    notes: 'AFRICLUB-linked digital item',
  ),
  FetRewardOption(
    reward: 'Partner Voucher',
    cost: '1000 FET',
    category: 'Utility',
    notes: 'Restaurant or retail partner reward',
  ),
];

const List<FanzoneScreenZone> fanzoneScreenZones = <FanzoneScreenZone>[
  FanzoneScreenZone(
    zone: 'B',
    title: 'Core Navigation Tabs',
    screens: <FanzoneScreenSpec>[
      FanzoneScreenSpec(
        code: 'S08',
        title: 'Home Feed',
        subtitle: 'Live and upcoming with personalization',
      ),
      FanzoneScreenSpec(
        code: 'S09',
        title: 'Live Matches',
        subtitle: 'In-play scores and prediction state',
      ),
      FanzoneScreenSpec(
        code: 'S10',
        title: 'Fixtures Browser',
        subtitle: 'Full fixture list with league filters',
      ),
      FanzoneScreenSpec(
        code: 'S11',
        title: 'Leaderboard',
        subtitle: 'Global, weekly, friends, and club',
      ),
      FanzoneScreenSpec(
        code: 'S12',
        title: 'My Predictions Hub',
        subtitle: 'Active, settled, and history',
      ),
      FanzoneScreenSpec(
        code: 'S13',
        title: 'Profile / Account',
        subtitle: 'Stats, tokens, and settings',
      ),
    ],
  ),
  FanzoneScreenZone(
    zone: 'C',
    title: 'Match and Prediction Zone',
    screens: <FanzoneScreenSpec>[
      FanzoneScreenSpec(
        code: 'S14',
        title: 'Match Detail Pre-match',
        subtitle: 'Stats, H2H, odds, and markets',
      ),
      FanzoneScreenSpec(
        code: 'S15',
        title: 'Match Detail Live',
        subtitle: 'Live score, timeline, and in-play markets',
      ),
      FanzoneScreenSpec(
        code: 'S16',
        title: 'Match Detail Post-match',
        subtitle: 'Final stats and settlement',
      ),
      FanzoneScreenSpec(
        code: 'S17',
        title: 'Market Selector Sheet',
        subtitle: 'Bottom sheet for 20 market types',
      ),
      FanzoneScreenSpec(
        code: 'S18',
        title: 'Prediction Slip',
        subtitle: 'Active picks, FET potential, and submit',
      ),
      FanzoneScreenSpec(
        code: 'S19',
        title: 'Prediction Confirmation',
        subtitle: 'Receipt and share moment',
      ),
      FanzoneScreenSpec(
        code: 'S20',
        title: 'Acca Builder',
        subtitle: 'Multi-match prediction builder',
      ),
      FanzoneScreenSpec(
        code: 'S21',
        title: 'Match Stats Deep Dive',
        subtitle: 'xG, heatmaps, form, and H2H',
      ),
      FanzoneScreenSpec(
        code: 'S22',
        title: 'Settlement Screen',
        subtitle: 'Win/loss animation and FET earned',
      ),
      FanzoneScreenSpec(
        code: 'S23',
        title: 'Prediction Detail',
        subtitle: 'Single prediction status and market',
      ),
    ],
  ),
  FanzoneScreenZone(
    zone: 'D',
    title: 'League and Competition Zone',
    screens: <FanzoneScreenSpec>[
      FanzoneScreenSpec(
        code: 'S24',
        title: 'League Hub',
        subtitle: 'Table, fixtures, and top scorers',
      ),
      FanzoneScreenSpec(
        code: 'S25',
        title: 'League Standings',
        subtitle: 'Full league table',
      ),
      FanzoneScreenSpec(
        code: 'S26',
        title: 'Competition Bracket',
        subtitle: 'Knockout view for CAF and world tournaments',
      ),
      FanzoneScreenSpec(
        code: 'S27',
        title: 'Team Profile',
        subtitle: 'Recent form, squad, and predictions',
      ),
    ],
  ),
  FanzoneScreenZone(
    zone: 'E',
    title: 'Token Economy Zone',
    screens: <FanzoneScreenSpec>[
      FanzoneScreenSpec(
        code: 'S28',
        title: 'FET Wallet',
        subtitle: 'Balance, history, and redemption',
      ),
      FanzoneScreenSpec(
        code: 'S29',
        title: 'Rewards Store',
        subtitle: 'Redeem FET for prizes or airtime',
      ),
      FanzoneScreenSpec(
        code: 'S30',
        title: 'Token History',
        subtitle: 'Earn and spend log',
      ),
      FanzoneScreenSpec(
        code: 'S31',
        title: 'Jackpot Challenge',
        subtitle: 'Weekly ten-match mega-predict',
      ),
      FanzoneScreenSpec(
        code: 'S32',
        title: 'Streak Tracker',
        subtitle: 'Daily correct prediction streak',
      ),
    ],
  ),
  FanzoneScreenZone(
    zone: 'F',
    title: 'Social and Gamification Zone',
    screens: <FanzoneScreenSpec>[
      FanzoneScreenSpec(
        code: 'S33',
        title: 'Friend Challenge',
        subtitle: 'Head-to-head prediction battle',
      ),
      FanzoneScreenSpec(
        code: 'S34',
        title: 'Friends List',
        subtitle: 'Search, follow, and compare',
      ),
      FanzoneScreenSpec(
        code: 'S35',
        title: 'Share Card Generator',
        subtitle: 'Prediction card for WhatsApp and X',
      ),
      FanzoneScreenSpec(
        code: 'S36',
        title: 'Badges and Achievements',
        subtitle: 'Unlocked milestones',
      ),
      FanzoneScreenSpec(
        code: 'S37',
        title: 'Club Fan Zone',
        subtitle: 'Team-specific community predictions',
      ),
    ],
  ),
];

const List<MarketOffer> marketOffers = <MarketOffer>[
  MarketOffer(
    category: 'Match',
    name: '1X2 Full Time',
    multiplierLabel: 'Base x1.0',
    options: <MarketOption>[
      MarketOption(label: '1', potentialFet: 12),
      MarketOption(label: 'X', potentialFet: 18),
      MarketOption(label: '2', potentialFet: 14),
    ],
  ),
  MarketOffer(
    category: 'Match',
    name: 'Double Chance',
    multiplierLabel: 'Safe x0.7',
    options: <MarketOption>[
      MarketOption(label: '1X', potentialFet: 8),
      MarketOption(label: 'X2', potentialFet: 9),
      MarketOption(label: '12', potentialFet: 10),
    ],
  ),
  MarketOffer(
    category: 'Goals',
    name: 'Both Teams to Score',
    multiplierLabel: 'Boost x1.2',
    options: <MarketOption>[
      MarketOption(label: 'Yes', potentialFet: 16),
      MarketOption(label: 'No', potentialFet: 18),
    ],
  ),
  MarketOffer(
    category: 'Goals',
    name: 'Over / Under 2.5',
    multiplierLabel: 'Boost x1.1',
    options: <MarketOption>[
      MarketOption(label: 'Over', potentialFet: 15),
      MarketOption(label: 'Under', potentialFet: 17),
    ],
  ),
  MarketOffer(
    category: 'Players',
    name: 'Anytime Goalscorer',
    multiplierLabel: 'Player x1.8',
    options: <MarketOption>[
      MarketOption(label: 'Nunez', potentialFet: 24),
      MarketOption(label: 'Saka', potentialFet: 22),
      MarketOption(label: 'Salah', potentialFet: 20),
    ],
  ),
  MarketOffer(
    category: 'Corners',
    name: 'Total Corners O/U 9.5',
    multiplierLabel: 'Set piece x1.4',
    options: <MarketOption>[
      MarketOption(label: 'Over', potentialFet: 18),
      MarketOption(label: 'Under', potentialFet: 18),
    ],
  ),
  MarketOffer(
    category: 'Cards',
    name: 'Total Cards O/U 3.5',
    multiplierLabel: 'Cards x1.5',
    options: <MarketOption>[
      MarketOption(label: 'Over', potentialFet: 20),
      MarketOption(label: 'Under', potentialFet: 19),
    ],
  ),
  MarketOffer(
    category: 'Specials',
    name: 'First Goal Time',
    multiplierLabel: 'Live x2.0',
    liveOnly: true,
    options: <MarketOption>[
      MarketOption(label: '0-10', potentialFet: 28),
      MarketOption(label: '11-20', potentialFet: 30),
      MarketOption(label: '21-30', potentialFet: 32),
    ],
  ),
];

List<PredictionSlipEntry> buildInitialPredictionSlipEntries() =>
    const <PredictionSlipEntry>[
      PredictionSlipEntry(
        fixture: 'Liverpool vs Arsenal',
        market: '1X2 Full Time',
        selection: 'Home Win',
        potentialFet: 12,
        note: 'Featured match',
      ),
      PredictionSlipEntry(
        fixture: 'APR FC vs Rayon Sports',
        market: 'Both Teams to Score',
        selection: 'Yes',
        potentialFet: 18,
        note: 'Rwanda Premier League',
      ),
    ];

const List<PredictionRecord> activePredictions = <PredictionRecord>[
  PredictionRecord(
    fixture: 'Liverpool vs Arsenal',
    market: '1X2 Full Time',
    selection: 'Home Win',
    status: PredictionRecordStatus.active,
    potentialFet: 12,
    resultLabel: 'Kickoff in 24m',
    timestampLabel: 'Today, 20:00',
  ),
  PredictionRecord(
    fixture: 'APR FC vs Rayon Sports',
    market: 'Both Teams to Score',
    selection: 'Yes',
    status: PredictionRecordStatus.active,
    potentialFet: 18,
    resultLabel: 'Slip locked in',
    timestampLabel: 'Today, 18:30',
  ),
];

const List<PredictionRecord> settledPredictions = <PredictionRecord>[
  PredictionRecord(
    fixture: 'Manchester City vs Chelsea',
    market: 'Over / Under 2.5',
    selection: 'Over',
    status: PredictionRecordStatus.won,
    potentialFet: 15,
    resultLabel: 'Won +15 FET',
    timestampLabel: 'Yesterday',
  ),
  PredictionRecord(
    fixture: 'Simba vs Yanga',
    market: 'Correct Score',
    selection: '1-1',
    status: PredictionRecordStatus.lost,
    potentialFet: 50,
    resultLabel: 'Lost',
    timestampLabel: 'Yesterday',
  ),
];

const List<PredictionRecord> predictionHistory = <PredictionRecord>[
  PredictionRecord(
    fixture: 'Rayon Sports vs Police FC',
    market: 'Double Chance',
    selection: '1X',
    status: PredictionRecordStatus.won,
    potentialFet: 8,
    resultLabel: 'Won +8 FET',
    timestampLabel: 'Last week',
  ),
  PredictionRecord(
    fixture: 'CAF Final',
    market: 'Anytime Goalscorer',
    selection: 'Salah',
    status: PredictionRecordStatus.lost,
    potentialFet: 20,
    resultLabel: 'Lost',
    timestampLabel: 'Last week',
  ),
  PredictionRecord(
    fixture: 'AFCON Final',
    market: '1X2 Full Time',
    selection: 'Draw',
    status: PredictionRecordStatus.won,
    potentialFet: 18,
    resultLabel: 'Won +18 FET',
    timestampLabel: '2 weeks ago',
  ),
];
