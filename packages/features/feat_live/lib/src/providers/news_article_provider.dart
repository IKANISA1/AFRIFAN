import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NewsArticlePhase { ready, syncing, degraded }

enum NewsArticleFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class NewsArticleFailure implements Exception {
  const NewsArticleFailure(this.kind);

  final NewsArticleFailureKind kind;

  static NewsArticleFailure fromError(Object error) {
    if (error is NewsArticleFailure) return error;
    if (error is TimeoutException) {
      return const NewsArticleFailure(NewsArticleFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const NewsArticleFailure(NewsArticleFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const NewsArticleFailure(NewsArticleFailureKind.conflict);
    }
    return const NewsArticleFailure(NewsArticleFailureKind.unknown);
  }

  @override
  String toString() => 'NewsArticleFailure(${kind.name})';
}

class NewsArticleSummary {
  const NewsArticleSummary({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class NewsArticleData {
  const NewsArticleData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.content,
    required this.createdAt,
    required this.related,
    this.imageUrl,
    this.imageProvenanceId = '',
    this.imageRightsApproved = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String content;
  final String createdAt;
  final List<NewsArticleSummary> related;
  final String? imageUrl;
  final String imageProvenanceId;
  final bool imageRightsApproved;
}

class NewsArticleState {
  const NewsArticleState({
    this.article,
    this.phase = NewsArticlePhase.ready,
    this.failure,
  });

  final NewsArticleData? article;
  final NewsArticlePhase phase;
  final NewsArticleFailure? failure;

  bool get linksBlocked => phase != NewsArticlePhase.ready || failure != null;

  NewsArticleState copyWith({
    NewsArticleData? article,
    NewsArticlePhase? phase,
    NewsArticleFailure? failure,
    bool clearFailure = false,
  }) {
    return NewsArticleState(
      article: article ?? this.article,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class NewsArticleGateway {
  Future<NewsArticleData?> load(String articleId);
}

class SupabaseNewsArticleGateway implements NewsArticleGateway {
  const SupabaseNewsArticleGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<NewsArticleData?> load(String articleId) async {
    final resolver = ClubScopeResolver(client: _client);
    final scope = await resolver.requireResolved();
    var articleQuery = _client
        .from('news_articles')
        .select()
        .eq('id', articleId);
    articleQuery = resolver.apply(articleQuery, scope);
    final article = await articleQuery.maybeSingle();
    if (article == null) return null;

    var relatedQuery = _client
        .from('news_articles')
        .select('id, title, subtitle')
        .eq('is_published', true)
        .neq('id', articleId);
    relatedQuery = resolver.apply(relatedQuery, scope);
    final related = await relatedQuery
        .order('sort_order', ascending: true)
        .limit(2);
    final row = Map<String, dynamic>.from(article);
    final provenanceId = row['image_provenance_id']?.toString().trim() ?? '';
    return NewsArticleData(
      id: row['id']?.toString() ?? articleId,
      title: row['title']?.toString() ?? 'Article',
      subtitle: row['subtitle']?.toString() ?? 'Club News',
      category: row['category']?.toString() ?? 'CLUB NEWS',
      content:
          row['body']?.toString() ??
          row['content']?.toString() ??
          row['subtitle']?.toString() ??
          'Club News',
      createdAt: row['created_at']?.toString() ?? '',
      related: List<Map<String, dynamic>>.from(related)
          .map(
            (entry) => NewsArticleSummary(
              id: entry['id']?.toString() ?? '',
              title: entry['title']?.toString() ?? 'Story',
              subtitle: entry['subtitle']?.toString() ?? '',
            ),
          )
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: false),
      imageUrl: row['image_url']?.toString(),
      imageProvenanceId: provenanceId,
      imageRightsApproved:
          row['image_rights_approved'] == true && provenanceId.isNotEmpty,
    );
  }
}

final newsArticleGatewayProvider = Provider<NewsArticleGateway>(
  (ref) => SupabaseNewsArticleGateway(ref.watch(supabaseClientProvider)),
);

final newsArticleLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final newsArticleLinksEnabledProvider = Provider<bool>((ref) => true);

final newsArticleProvider =
    StateNotifierProvider.family<
      NewsArticleController,
      AsyncValue<NewsArticleState>,
      String
    >((ref, articleId) {
      return NewsArticleController(
        ref.watch(newsArticleGatewayProvider),
        articleId,
        loadTimeout: ref.watch(newsArticleLoadTimeoutProvider),
      );
    });

class NewsArticleController
    extends StateNotifier<AsyncValue<NewsArticleState>> {
  NewsArticleController(
    this._gateway,
    this._articleId, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
  }) : _loadTimeout = loadTimeout,
       super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(load());
  }

  final NewsArticleGateway _gateway;
  final String _articleId;
  final Duration _loadTimeout;
  bool _loading = false;

  Future<void> load() => _load(preserveCurrent: false);

  Future<void> refresh() => _load(preserveCurrent: true);

  Future<void> _load({required bool preserveCurrent}) async {
    if (_loading) return;
    _loading = true;
    final previous = state.valueOrNull;
    state = preserveCurrent && previous?.article != null
        ? const AsyncLoading<NewsArticleState>().copyWithPrevious(state)
        : const AsyncLoading<NewsArticleState>();
    try {
      if (!ConnectivityService.isOnline) {
        throw const NewsArticleFailure(NewsArticleFailureKind.offline);
      }
      final article = await _gateway.load(_articleId).timeout(_loadTimeout);
      state = AsyncValue.data(NewsArticleState(article: article));
    } catch (error, stackTrace) {
      final failure = NewsArticleFailure.fromError(error);
      state = previous?.article != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: NewsArticlePhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }
}
