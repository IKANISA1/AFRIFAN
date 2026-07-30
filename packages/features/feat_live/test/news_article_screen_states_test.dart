import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_live/src/providers/news_article_provider.dart';
import 'package:feat_live/src/screens/news_article_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldens = <String, String>{
  'loading': 'goldens/news_article_state_loading_dark_390x844.png',
  'empty': 'goldens/news_article_state_empty_dark_390x844.png',
  'error': 'goldens/news_article_state_error_dark_390x844.png',
  'offline': 'goldens/news_article_state_offline_dark_390x844.png',
  'permission_denied':
      'goldens/news_article_state_permission_denied_dark_390x844.png',
  'disabled': 'goldens/news_article_state_disabled_dark_390x844.png',
  'focused': 'goldens/news_article_state_focused_dark_390x844.png',
  'pressed': 'goldens/news_article_state_pressed_dark_390x844.png',
  'selected': 'goldens/news_article_state_selected_dark_390x844.png',
  'large_text': 'goldens/news_article_state_large_text_dark_320x720.png',
  'reduced_motion':
      'goldens/news_article_state_reduced_motion_dark_390x844.png',
  'dark': 'goldens/news_article_state_dark_dark_390x844.png',
  'light': 'goldens/news_article_state_light_light_390x844.png',
  'syncing': 'goldens/news_article_state_syncing_dark_390x844.png',
  'conflict': 'goldens/news_article_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/news_article_state_security_timeout_dark_390x844.png',
};

class _Gateway implements NewsArticleGateway {
  @override
  Future<NewsArticleData?> load(String articleId) async => _article();
}

class _Controller extends NewsArticleController {
  _Controller(AsyncValue<NewsArticleState> value)
    : super(_Gateway(), 'article-1', autoLoad: false) {
    state = value;
  }

  int refreshCount = 0;

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

NewsArticleData _article() {
  return const NewsArticleData(
    id: 'article-1',
    title: 'Derby preparation enters final phase',
    subtitle: 'The squad completed its final session.',
    category: 'TEAM NEWS',
    content:
        'Rayon Sports completed the final preparation session at Amahoro Stadium. The squad focused on shape, recovery, and set pieces before the derby.',
    createdAt: '2026-07-28T09:00:00Z',
    related: <NewsArticleSummary>[
      NewsArticleSummary(
        id: 'article-2',
        title: 'Supporter matchday guide',
        subtitle: 'Access, timing, and stadium information.',
      ),
    ],
  );
}

NewsArticleState _ready({
  NewsArticlePhase phase = NewsArticlePhase.ready,
  NewsArticleFailure? failure,
}) {
  return NewsArticleState(article: _article(), phase: phase, failure: failure);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('News article refreshes after reconnect', (tester) async {
    ConnectivityService.setOnlineForTest(false);
    final controller = _Controller(
      const AsyncError<NewsArticleState>(
        NewsArticleFailure(NewsArticleFailureKind.offline),
        StackTrace.empty,
      ),
    );
    await _pumpRoute(tester, controller: controller, capture: false);
    expect(find.text('Article offline'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    await tester.pumpAndSettle();

    expect(controller.refreshCount, 1);
    expect(find.text('Connection restored'), findsOneWidget);
  });

  testWidgets('golden News article loading state', (tester) async {
    await _pumpState(
      tester,
      id: 'loading',
      value: const AsyncLoading<NewsArticleState>(),
      settle: false,
    );
  });

  testWidgets('golden News article empty state', (tester) async {
    await _pumpState(
      tester,
      id: 'empty',
      value: const AsyncData<NewsArticleState>(NewsArticleState()),
      check: (_) async =>
          expect(find.text('Article not found'), findsOneWidget),
    );
  });

  testWidgets('golden News article error state', (tester) async {
    await _pumpState(
      tester,
      id: 'error',
      value: const AsyncError<NewsArticleState>(
        NewsArticleFailure(NewsArticleFailureKind.unknown),
        StackTrace.empty,
      ),
      check: (_) async =>
          expect(find.text('Article unavailable'), findsOneWidget),
    );
  });

  testWidgets('golden News article offline state', (tester) async {
    await _pumpState(
      tester,
      id: 'offline',
      value: AsyncData<NewsArticleState>(_ready()),
      online: false,
      check: (_) async {
        expect(find.text('Showing saved article'), findsOneWidget);
      },
    );
  });

  testWidgets('golden News article permission-denied state', (tester) async {
    await _pumpState(
      tester,
      id: 'permission_denied',
      value: const AsyncError<NewsArticleState>(
        NewsArticleFailure(NewsArticleFailureKind.permissionDenied),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('Article access unavailable'), findsOneWidget);
        expect(find.text('Refresh'), findsNothing);
      },
    );
  });

  testWidgets('golden News article disabled state', (tester) async {
    await _pumpState(
      tester,
      id: 'disabled',
      value: AsyncData<NewsArticleState>(_ready()),
      linksEnabled: false,
      check: (_) async {
        expect(find.text('Related stories unavailable'), findsOneWidget);
      },
    );
  });

  testWidgets('golden News article focused state', (tester) async {
    final focusNode = FocusNode(debugLabel: 'related-article-focus');
    addTearDown(focusNode.dispose);
    final previous = FocusManager.instance.highlightStrategy;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpState(
      tester,
      id: 'focused',
      value: AsyncData<NewsArticleState>(_ready()),
      relatedFocusNode: focusNode,
      check: (tester) async {
        final card = find.byKey(
          const ValueKey<String>('news-related-article-2'),
        );
        await tester.scrollUntilVisible(card, 260);
        focusNode.requestFocus();
        await tester.pumpAndSettle();
        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  testWidgets('golden News article pressed state', (tester) async {
    TestGesture? gesture;
    addTearDown(() async => gesture?.up());
    await _pumpState(
      tester,
      id: 'pressed',
      value: AsyncData<NewsArticleState>(_ready()),
      check: (tester) async {
        final card = find.byKey(
          const ValueKey<String>('news-related-article-2'),
        );
        await tester.scrollUntilVisible(card, 260);
        gesture = await tester.startGesture(tester.getCenter(card));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 40));
        final surfaces = tester.widgetList<AnimatedContainer>(
          find.descendant(of: card, matching: find.byType(AnimatedContainer)),
        );
        expect(
          surfaces.any(
            (surface) =>
                (surface.decoration as BoxDecoration?)?.boxShadow?.length == 2,
          ),
          isTrue,
        );
      },
    );
  });

  testWidgets('golden News article selected state', (tester) async {
    await _pumpState(
      tester,
      id: 'selected',
      value: AsyncData<NewsArticleState>(_ready()),
      check: (_) async {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                widget.properties.label ==
                    'Selected article Derby preparation enters final phase',
          ),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('golden News article large-text state', (tester) async {
    await _pumpState(
      tester,
      id: 'large_text',
      value: AsyncData<NewsArticleState>(_ready()),
      size: const Size(320, 720),
      textScale: 2,
      check: (tester) async {
        await tester.scrollUntilVisible(
          find.text('Supporter matchday guide'),
          260,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('golden News article reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      id: 'reduced_motion',
      value: AsyncData<NewsArticleState>(_ready()),
      reducedMotion: true,
      check: (tester) async {
        expect(
          MediaQuery.of(
            tester.element(find.byType(CustomScrollView)),
          ).disableAnimations,
          isTrue,
        );
      },
    );
  });

  testWidgets('golden News article dark state', (tester) async {
    await _pumpState(
      tester,
      id: 'dark',
      value: AsyncData<NewsArticleState>(_ready()),
    );
  });

  testWidgets('golden News article light state', (tester) async {
    await _pumpState(
      tester,
      id: 'light',
      value: AsyncData<NewsArticleState>(_ready()),
      brightness: Brightness.light,
    );
  });

  testWidgets('golden News article syncing state', (tester) async {
    await _pumpState(
      tester,
      id: 'syncing',
      value: AsyncData<NewsArticleState>(
        _ready(phase: NewsArticlePhase.syncing),
      ),
      settle: false,
      check: (_) async {
        expect(find.text('Refreshing article'), findsOneWidget);
      },
    );
  });

  testWidgets('golden News article conflict state', (tester) async {
    await _pumpState(
      tester,
      id: 'conflict',
      value: AsyncData<NewsArticleState>(
        _ready(
          phase: NewsArticlePhase.degraded,
          failure: const NewsArticleFailure(NewsArticleFailureKind.conflict),
        ),
      ),
      check: (_) async {
        expect(find.text('Article changed'), findsOneWidget);
        expect(find.text('REFRESH ARTICLE'), findsOneWidget);
      },
    );
  });

  testWidgets('golden News article security-timeout state', (tester) async {
    await _pumpState(
      tester,
      id: 'security_timeout',
      value: const AsyncError<NewsArticleState>(
        NewsArticleFailure(NewsArticleFailureKind.securityTimeout),
        StackTrace.empty,
      ),
      check: (_) async {
        expect(find.text('Article security check timed out'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpState(
  WidgetTester tester, {
  required String id,
  required AsyncValue<NewsArticleState> value,
  bool online = true,
  bool linksEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  FocusNode? relatedFocusNode,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? check,
}) async {
  ConnectivityService.setOnlineForTest(online);
  await _pumpRoute(
    tester,
    controller: _Controller(value),
    linksEnabled: linksEnabled,
    brightness: brightness,
    size: size,
    textScale: textScale,
    reducedMotion: reducedMotion,
    relatedFocusNode: relatedFocusNode,
    settle: settle,
    check: check,
    goldenPath: _goldens[id]!,
  );
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _Controller controller,
  bool capture = true,
  bool linksEnabled = true,
  Brightness brightness = Brightness.dark,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  FocusNode? relatedFocusNode,
  bool settle = true,
  Future<void> Function(WidgetTester tester)? check,
  String? goldenPath,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(brightness);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  final router = GoRouter(
    initialLocation: '/live/news/article-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/live/news/:articleId',
        builder: (context, state) => NewsArticleScreen(
          articleId: state.pathParameters['articleId']!,
          relatedFocusNode: relatedFocusNode,
        ),
      ),
      GoRoute(
        path: '/fanzone/match/:fixtureId',
        builder: (context, state) => const Scaffold(body: Text('Live match')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        newsArticleProvider.overrideWith((ref, articleId) => controller),
        newsArticleLinksEnabledProvider.overrideWithValue(linksEnabled),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          );
        },
        routerConfig: router,
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await check?.call(tester);
  if (capture) {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenPath!));
  }
}
