import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_live/src/providers/news_article_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements NewsArticleGateway {
  NewsArticleData? article = _article();
  Object? error;
  Completer<NewsArticleData?>? completer;
  int calls = 0;

  @override
  Future<NewsArticleData?> load(String articleId) {
    calls++;
    if (error case final value?) return Future.error(value);
    return completer?.future ?? Future.value(article);
  }
}

NewsArticleData _article() {
  return const NewsArticleData(
    id: 'article-1',
    title: 'Derby preparation enters final phase',
    subtitle: 'The squad completed its final session.',
    category: 'TEAM NEWS',
    content: 'Rayon Sports completed the final preparation session.',
    createdAt: '2026-07-28T09:00:00Z',
    related: <NewsArticleSummary>[
      NewsArticleSummary(
        id: 'article-2',
        title: 'Supporter guide',
        subtitle: 'Matchday access information.',
      ),
    ],
  );
}

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads a confirmed article', () async {
    final gateway = _Gateway();
    final controller = NewsArticleController(
      gateway,
      'article-1',
      autoLoad: false,
    );

    await controller.load();

    expect(controller.state.value!.article?.id, 'article-1');
    expect(controller.state.value!.phase, NewsArticlePhase.ready);
  });

  test('represents a missing article as empty data', () async {
    final gateway = _Gateway()..article = null;
    final controller = NewsArticleController(
      gateway,
      'article-missing',
      autoLoad: false,
    );

    await controller.load();

    expect(controller.state.value!.article, isNull);
    expect(controller.state.value, isNotNull);
  });

  test('fails before gateway access when offline', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway();
    final controller = NewsArticleController(
      gateway,
      'article-1',
      autoLoad: false,
    );

    await controller.load();

    expect(gateway.calls, 0);
    expect(
      (controller.state.error! as NewsArticleFailure).kind,
      NewsArticleFailureKind.offline,
    );
  });

  test('maps a bounded load timeout to security timeout', () async {
    final gateway = _Gateway()..completer = Completer<NewsArticleData?>();
    final controller = NewsArticleController(
      gateway,
      'article-1',
      autoLoad: false,
      loadTimeout: const Duration(milliseconds: 1),
    );

    await controller.load();

    expect(
      (controller.state.error! as NewsArticleFailure).kind,
      NewsArticleFailureKind.securityTimeout,
    );
  });

  test('retains confirmed article when refresh conflicts', () async {
    final gateway = _Gateway();
    final controller = NewsArticleController(
      gateway,
      'article-1',
      autoLoad: false,
    );
    await controller.load();
    gateway.error = StateError('stale revision conflict');

    await controller.refresh();

    expect(controller.state.value!.article?.id, 'article-1');
    expect(controller.state.value!.phase, NewsArticlePhase.degraded);
    expect(
      controller.state.value!.failure?.kind,
      NewsArticleFailureKind.conflict,
    );
  });

  test('coalesces overlapping refresh requests', () async {
    final gateway = _Gateway()..completer = Completer<NewsArticleData?>();
    final controller = NewsArticleController(
      gateway,
      'article-1',
      autoLoad: false,
    );

    final first = controller.refresh();
    final second = controller.refresh();
    gateway.completer!.complete(_article());
    await Future.wait(<Future<void>>[first, second]);

    expect(gateway.calls, 1);
  });

  test('permission failures map to a stable typed category', () async {
    final gateway = _Gateway()
      ..error = StateError('row-level security permission denied');
    final controller = NewsArticleController(
      gateway,
      'article-1',
      autoLoad: false,
    );

    await controller.load();

    expect(
      (controller.state.error! as NewsArticleFailure).kind,
      NewsArticleFailureKind.permissionDenied,
    );
  });
}
