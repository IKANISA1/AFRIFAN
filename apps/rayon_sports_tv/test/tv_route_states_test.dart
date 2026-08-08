import 'dart:convert';
import 'dart:io';

import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayon_sports_tv/main.dart';

const _config = RayonSportsConfig();
const _goldenKey = ValueKey<String>('tv-route-state-golden-v2');
final _now = DateTime.utc(2026, 7, 30, 18);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final crossClientFixture = _loadCrossClientFixture();

  setUpAll(() async {
    await _loadGoldenRoboto();
    ColorTokens.init(_config.colors);
  });

  testWidgets('golden generated pairing challenge at 720p', (tester) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.awaitingOwner,
        challenge: TvBootstrapChallenge(
          challenge: 'TV4K8M2Q',
          expiresAt: _now.add(const Duration(minutes: 5)),
          qrPayload: 'africlub://my-tvs/pair?challenge=TV4K8M2Q',
        ),
      ),
    );

    expect(find.text('TV4K8M2Q'), findsOneWidget);
    await _match(tester, 'tv_v2_pairing_challenge_rw_1280x720.png');
  });

  testWidgets('golden live question and leaderboard at 720p', (tester) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.ready,
        projection: _projection(),
        lastUpdated: _now,
      ),
      locale: const Locale('en'),
    );

    expect(find.text('Who scored first?'), findsOneWidget);
    expect(find.text('Fan 042'), findsOneWidget);
    await _match(tester, 'tv_v2_question_en_1280x720.png');
  });

  testWidgets('golden reveal highlights the correct answer', (tester) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.ready,
        projection: _projection(phase: 'reveal'),
        lastUpdated: _now,
      ),
      locale: const Locale('fr'),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Bonne réponse : Player A',
      ),
      findsOneWidget,
    );
    await _match(tester, 'tv_v2_reveal_fr_1280x720.png');
  });

  testWidgets('golden offline state retains confirmed projection', (
    tester,
  ) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.offline,
        projection: _projection(phase: 'paused'),
        lastUpdated: _now,
        failure: const TvRuntimeFailure(TvRuntimeFailureKind.unavailable),
      ),
    );

    expect(
      find.text(
        lookupAfriLocalizations(const Locale('rw')).tvOfflineLastConfirmed,
      ),
      findsOneWidget,
    );
    await _match(tester, 'tv_v2_offline_retained_rw_1280x720.png');
  });

  testWidgets('golden paired display with no assigned game', (tester) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.empty,
        projection: TvGameProjection(
          status: 'empty',
          displayId: 'display-1',
          clubId: 'club-1',
          serverTime: _now,
        ),
        lastUpdated: _now,
      ),
      locale: const Locale('en'),
    );

    expect(find.text('TV paired'), findsOneWidget);
    await _match(tester, 'tv_v2_empty_en_1280x720.png');
  });

  testWidgets('golden large-text game reflows vertically', (tester) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.ready,
        projection: _projection(phase: 'completed'),
        lastUpdated: _now,
      ),
      textScaler: const TextScaler.linear(1.7),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await _match(tester, 'tv_v2_completed_large_text_rw_1280x720.png');
  });

  testWidgets('GAME-QA-05 golden long copy at 200 percent', (tester) async {
    await _pumpState(
      tester,
      TvRuntimeState(
        status: TvRuntimeStatus.ready,
        projection: _projection(
          sessionTitle:
              'Rayon Sports international supporters matchday knowledge challenge',
          questionPrompt:
              'Which historic moment best represents the club, its supporters, and this matchday competition?',
        ),
        lastUpdated: _now,
      ),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _match(
      tester,
      'tv_v2_question_long_copy_rw_200_percent_1280x720.png',
    );
  });

  for (final state in crossClientFixture.states) {
    testWidgets(
      'GAME-QA-02 native TV renders ${state.id} authoritative state',
      (tester) async {
        final projection = _crossClientProjection(crossClientFixture, state);

        await _pumpState(
          tester,
          TvRuntimeState(
            status: TvRuntimeStatus.ready,
            projection: projection,
            lastUpdated: _now,
          ),
          locale: const Locale('en'),
        );

        expect(find.text(state.tvRenderText), findsWidgets);
        expect(projection.sessionVersion, state.sessionVersion);
        expect(projection.questionVersion, state.questionVersion);
        expect(projection.eventSequence, state.eventSequence);
        expect(projection.question?.correctOptionKey, state.correctOptionKey);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

TvGameProjection _crossClientProjection(
  _CrossClientFixture fixture,
  _CrossClientState state,
) {
  return TvGameProjection(
    status: 'ready',
    displayId: 'display-1',
    clubId: 'club-1',
    serverTime: DateTime.utc(2026, 8, 1, 14, 0, state.eventSequence),
    sessionId: fixture.sessionId,
    sessionTitle: fixture.sessionTitle,
    phase: state.phase,
    sessionVersion: state.sessionVersion,
    questionVersion: state.questionVersion,
    eventSequence: state.eventSequence,
    phaseDeadline: state.phase == 'question_open'
        ? DateTime.utc(2026, 8, 1, 14, 0, 30)
        : null,
    question: state.questionPrompt == null
        ? null
        : TvQuestionProjection(
            id: 'question-${state.questionOrdinal}',
            ordinal: state.questionOrdinal!,
            prompt: state.questionPrompt!,
            options: const <TvQuestionOption>[
              TvQuestionOption(key: 'a', label: 'Player A'),
              TvQuestionOption(key: 'b', label: '1968'),
            ],
            correctOptionKey: state.correctOptionKey,
          ),
    leaderboard: <TvLeaderboardEntry>[
      TvLeaderboardEntry(
        rank: 1,
        publicAlias: 'Fan 042',
        score: state.eventSequence * 10,
      ),
    ],
  );
}

_CrossClientFixture _loadCrossClientFixture() {
  final json =
      jsonDecode(_findCrossClientFixture().readAsStringSync())
          as Map<String, dynamic>;
  return _CrossClientFixture(
    sessionId: json['session_id']! as String,
    sessionTitle: json['session_title']! as String,
    states: (json['states']! as List<dynamic>)
        .map(
          (value) => _CrossClientState.fromJson(value as Map<String, dynamic>),
        )
        .toList(growable: false),
  );
}

File _findCrossClientFixture() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = File(
      '${directory.path}/docs/architecture/'
      'live-games-v2-cross-client-fixtures.json',
    );
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate the GAME-QA-02 fixture.');
    }
    directory = parent;
  }
}

class _CrossClientFixture {
  const _CrossClientFixture({
    required this.sessionId,
    required this.sessionTitle,
    required this.states,
  });

  final String sessionId;
  final String sessionTitle;
  final List<_CrossClientState> states;
}

class _CrossClientState {
  const _CrossClientState({
    required this.id,
    required this.phase,
    required this.sessionVersion,
    required this.questionVersion,
    required this.eventSequence,
    required this.questionOrdinal,
    required this.questionPrompt,
    required this.correctOptionKey,
    required this.tvRenderText,
  });

  factory _CrossClientState.fromJson(Map<String, dynamic> json) {
    return _CrossClientState(
      id: json['id']! as String,
      phase: json['phase']! as String,
      sessionVersion: json['session_version']! as int,
      questionVersion: json['question_version']! as int,
      eventSequence: json['event_sequence']! as int,
      questionOrdinal: json['question_ordinal'] as int?,
      questionPrompt: json['question_prompt'] as String?,
      correctOptionKey: json['correct_option_key'] as String?,
      tvRenderText: json['tv_render_text']! as String,
    );
  }

  final String id;
  final String phase;
  final int sessionVersion;
  final int questionVersion;
  final int eventSequence;
  final int? questionOrdinal;
  final String? questionPrompt;
  final String? correctOptionKey;
  final String tvRenderText;
}

TvGameProjection _projection({
  String phase = 'question_open',
  String sessionTitle = 'Matchday knowledge challenge',
  String questionPrompt = 'Who scored first?',
}) {
  final reveal = phase == 'reveal' || phase == 'completed';
  return TvGameProjection(
    status: 'ready',
    displayId: 'display-1',
    clubId: 'club-1',
    serverTime: _now,
    sessionId: 'session-1',
    sessionTitle: sessionTitle,
    phase: phase,
    sessionVersion: 4,
    questionVersion: 2,
    eventSequence: 8,
    phaseDeadline: phase == 'question_open'
        ? DateTime.now().toUtc().add(const Duration(seconds: 45))
        : null,
    question: TvQuestionProjection(
      id: 'question-1',
      ordinal: 1,
      prompt: questionPrompt,
      options: const <TvQuestionOption>[
        TvQuestionOption(key: 'a', label: 'Player A'),
        TvQuestionOption(key: 'b', label: 'Player B'),
      ],
      correctOptionKey: reveal ? 'a' : null,
    ),
    leaderboard: const <TvLeaderboardEntry>[
      TvLeaderboardEntry(rank: 1, publicAlias: 'Fan 042', score: 120),
      TvLeaderboardEntry(rank: 2, publicAlias: 'Blue 118', score: 95),
      TvLeaderboardEntry(rank: 3, publicAlias: 'Rayon 207', score: 80),
    ],
  );
}

Future<void> _pumpState(
  WidgetTester tester,
  TvRuntimeState state, {
  Locale locale = const Locale('rw'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  ColorTokens.init(_config.colors);
  ColorTokens.setBrightness(Brightness.dark);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);

  await tester.pumpWidget(
    MaterialApp(
      theme: ClubTheme.from(_config),
      locale: locale.languageCode == 'rw' ? const Locale('en') : locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('fr')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AfriLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AfriLocalizationsScope(
        locale: locale,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: RepaintBoundary(
        key: _goldenKey,
        child: RayonSportsTvScreen(state: state, onRetry: () {}),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> _match(WidgetTester tester, String filename) {
  return expectLater(
    find.byKey(_goldenKey),
    matchesGoldenFile('goldens/$filename'),
  );
}

Future<void> _loadGoldenRoboto() async {
  final loader = FontLoader('GoldenRoboto');
  loader.addFont(_loadGoldenRobotoBytes());
  await loader.load();
}

Future<ByteData> _loadGoldenRobotoBytes() async {
  const assetPath = 'packages/flutter/fonts/Roboto-Regular.ttf';
  try {
    return await rootBundle.load(assetPath);
  } catch (_) {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
    final candidates = <File>[
      File(
        '/Volumes/PRO-G40/flutter_3_44/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
      if (flutterRoot.isNotEmpty)
        File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return ByteData.sublistView(await candidate.readAsBytes());
      }
    }
    throw FileSystemException('Unable to locate Roboto-Regular.ttf');
  }
}
