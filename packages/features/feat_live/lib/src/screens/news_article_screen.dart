import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/news_article_provider.dart';

class NewsArticleScreen extends ConsumerStatefulWidget {
  const NewsArticleScreen({
    required this.articleId,
    this.relatedFocusNode,
    super.key,
  });

  final String articleId;
  final FocusNode? relatedFocusNode;

  @override
  ConsumerState<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends ConsumerState<NewsArticleScreen> {
  bool? _lastOnline;

  void _leaveArticle() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/fanzone/match/live');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncArticle = ref.watch(newsArticleProvider(widget.articleId));
    final configuredLinksEnabled = ref.watch(newsArticleLinksEnabledProvider);
    return ConnectivityBuilder(
      builder: (context, isOnline) {
        final previousOnline = _lastOnline;
        _lastOnline = isOnline;
        if (previousOnline == false && isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              ref
                  .read(newsArticleProvider(widget.articleId).notifier)
                  .refresh(),
            );
          });
        }
        return asyncArticle.when(
          loading: _buildLoading,
          error: (error, _) => _buildFailure(error, isOnline),
          data: (routeState) {
            final article = routeState.article;
            if (article == null) return _buildEmpty();
            return _buildArticle(
              article: article,
              routeState: routeState,
              configuredLinksEnabled: configuredLinksEnabled,
              isOnline: isOnline,
              isRefreshing: asyncArticle.isRefreshing,
            );
          },
        );
      },
    );
  }

  Widget _buildLoading() {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveArticle,
          tooltip: context.afriL10n.authBack,
        ),
      ),
      scrollable: false,
      child: const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return _buildStateScaffold(
      AfriStateView.empty(
        title: context.afriL10n.newsArticleNotFoundTitle,
        message: context.afriL10n.newsArticleNotFoundMessage,
        icon: AfriIcons.article,
        actionLabel: context.afriL10n.newsBackToLiveMatch,
        onAction: _leaveArticle,
      ),
    );
  }

  Widget _buildFailure(Object error, bool isOnline) {
    final failure = NewsArticleFailure.fromError(error);
    final content = _NewsArticleFailureContent.fromFailure(
      context.afriL10n,
      failure,
      isOnline,
    );
    final onAction = content.canRefresh
        ? () => unawaited(
            ref.read(newsArticleProvider(widget.articleId).notifier).refresh(),
          )
        : null;
    final view = switch (failure.kind) {
      NewsArticleFailureKind.offline => AfriStateView.offline(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? context.afriL10n.liveRefresh : null,
        onAction: onAction,
      ),
      _ => AfriStateView.error(
        title: content.title,
        message: content.message,
        actionLabel: content.canRefresh ? context.afriL10n.liveRefresh : null,
        onAction: onAction,
      ),
    };
    return _buildStateScaffold(view);
  }

  Widget _buildStateScaffold(Widget stateView) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(context.afriL10n.newsClubNews),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: _leaveArticle,
          tooltip: context.afriL10n.authBack,
        ),
      ),
      scrollable: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: stateView,
        ),
      ),
    );
  }

  Widget _buildArticle({
    required NewsArticleData article,
    required NewsArticleState routeState,
    required bool configuredLinksEnabled,
    required bool isOnline,
    required bool isRefreshing,
  }) {
    final linksEnabled =
        configuredLinksEnabled && isOnline && !routeState.linksBlocked;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: false,
      child: AfriRefreshIndicator(
        onRefresh: () =>
            ref.read(newsArticleProvider(widget.articleId).notifier).refresh(),
        color: ColorTokens.clubAccent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            AfriSliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: ColorTokens.background,
              leading: AfriIconButton(
                icon: AfriIcons.back,
                onTap: _leaveArticle,
                tooltip: context.afriL10n.authBack,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background:
                    article.imageUrl != null && article.imageUrl!.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          AfriGovernedCachedImage(
                            imageUrl: article.imageUrl,
                            semanticLabel: context.afriL10n
                                .newsArticleImageSemantic(article.title),
                            provenanceId: article.imageProvenanceId.isEmpty
                                ? 'news:${widget.articleId}:unapproved'
                                : article.imageProvenanceId,
                            rightsApproved: article.imageRightsApproved,
                            fit: BoxFit.cover,
                            borderRadius: 0,
                            errorFallback: _ArticleHeroFallback(
                              category: article.category,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: ColorTokens.imageScrimGradient(
                                color: ColorTokens.background,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _ArticleHeroFallback(category: article.category),
              ),
            ),
            if (isRefreshing || routeState.phase == NewsArticlePhase.syncing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: AfriStateBanner(
                    icon: AfriIcons.refresh,
                    title: context.afriL10n.newsRefreshingTitle,
                    subtitle: context.afriL10n.newsRefreshingMessage,
                    tone: AfriStateBannerTone.info,
                    compact: true,
                  ),
                ),
              ),
            if (!configuredLinksEnabled)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: AfriStateBanner(
                    icon: AfriIcons.lock,
                    title: context.afriL10n.newsRelatedUnavailableTitle,
                    subtitle: context.afriL10n.newsRelatedUnavailableMessage,
                    tone: AfriStateBannerTone.warning,
                    compact: true,
                  ),
                ),
              )
            else if (!isOnline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: AfriStateBanner(
                    icon: AfriIcons.offline,
                    title: context.afriL10n.newsShowingSavedTitle,
                    subtitle: context.afriL10n.newsShowingSavedMessage,
                    tone: AfriStateBannerTone.warning,
                    compact: true,
                  ),
                ),
              )
            else if (routeState.failure != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing4,
                    SpacingTokens.spacing6,
                    0,
                  ),
                  child: _RetainedArticleFailureBanner(
                    failure: routeState.failure!,
                    onRefresh:
                        routeState.failure!.kind ==
                            NewsArticleFailureKind.permissionDenied
                        ? null
                        : () => unawaited(
                            ref
                                .read(
                                  newsArticleProvider(
                                    widget.articleId,
                                  ).notifier,
                                )
                                .refresh(),
                          ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AfriStatusChip(
                      label: article.category,
                      tone: AfriStatusTone.info,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Semantics(
                      selected: true,
                      label: context.afriL10n.newsSelectedSemantic(
                        article.title,
                      ),
                      child: Text(
                        article.title,
                        style: TypographyTokens.headlineLarge().copyWith(
                          color: ColorTokens.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      context.afriL10n.newsMetadata(
                        article.createdAt.isEmpty
                            ? context.afriL10n.newsToday
                            : article.createdAt.split('T').first,
                      ),
                      style: TypographyTokens.bodySmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing6),
                    Text(
                      article.content,
                      style: TypographyTokens.bodyLarge().copyWith(height: 1.6),
                    ),
                    if (article.related.isNotEmpty) ...[
                      const SizedBox(height: SpacingTokens.spacing8),
                      AfriSectionHeader(
                        title: context.afriL10n.newsRelatedIntel,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      ...article.related.indexed.map((indexedEntry) {
                        final (index, entry) = indexedEntry;
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: _RelatedArticle(
                            key: ValueKey<String>('news-related-${entry.id}'),
                            title: entry.title,
                            subtitle: entry.subtitle,
                            enabled: linksEnabled,
                            focusNode: index == 0
                                ? widget.relatedFocusNode
                                : null,
                            onTap: () => context.push('/live/news/${entry.id}'),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleHeroFallback extends StatelessWidget {
  const _ArticleHeroFallback({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ColorTokens.universalGradient(
          colors: [
            ColorTokens.clubPrimary.withValues(alpha: 0.4),
            ColorTokens.clubSecondary,
            ColorTokens.surfaceContainerLowest,
          ],
        ),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Text(
        category,
        style: TypographyTokens.headlineLarge().copyWith(
          color: ColorTokens.onSurface,
        ),
      ),
    );
  }
}

class _RetainedArticleFailureBanner extends StatelessWidget {
  const _RetainedArticleFailureBanner({required this.failure, this.onRefresh});

  final NewsArticleFailure failure;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = _NewsArticleFailureContent.fromFailure(
      context.afriL10n,
      failure,
      true,
    );
    return Column(
      children: [
        AfriStateBanner(
          icon: failure.kind == NewsArticleFailureKind.permissionDenied
              ? AfriIcons.lock
              : failure.kind == NewsArticleFailureKind.offline
              ? AfriIcons.offline
              : AfriIcons.statusWarning,
          title: content.title,
          subtitle: content.message,
          tone: AfriStateBannerTone.warning,
          compact: true,
        ),
        if (onRefresh != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            key: const ValueKey<String>('news-article-refresh-action'),
            label: context.afriL10n.newsRefreshArticle,
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            labelMaxLines: 2,
            onTap: onRefresh!,
          ),
        ],
      ],
    );
  }
}

class _NewsArticleFailureContent {
  const _NewsArticleFailureContent({
    required this.title,
    required this.message,
    required this.canRefresh,
  });

  final String title;
  final String message;
  final bool canRefresh;

  factory _NewsArticleFailureContent.fromFailure(
    AfriLocalizations l10n,
    NewsArticleFailure failure,
    bool isOnline,
  ) {
    return switch (failure.kind) {
      NewsArticleFailureKind.offline => _NewsArticleFailureContent(
        title: isOnline ? l10n.newsConnectionRestored : l10n.newsArticleOffline,
        message: isOnline ? l10n.newsRefreshLatest : l10n.newsReconnectLatest,
        canRefresh: isOnline,
      ),
      NewsArticleFailureKind.permissionDenied => _NewsArticleFailureContent(
        title: l10n.newsAccessUnavailableTitle,
        message: l10n.newsAccessUnavailableMessage,
        canRefresh: false,
      ),
      NewsArticleFailureKind.conflict => _NewsArticleFailureContent(
        title: l10n.newsChangedTitle,
        message: l10n.newsChangedMessage,
        canRefresh: isOnline,
      ),
      NewsArticleFailureKind.securityTimeout => _NewsArticleFailureContent(
        title: l10n.newsSecurityTimeoutTitle,
        message: l10n.newsSecurityTimeoutMessage,
        canRefresh: isOnline,
      ),
      NewsArticleFailureKind.unknown => _NewsArticleFailureContent(
        title: l10n.newsUnavailableTitle,
        message: l10n.newsUnavailableMessage,
        canRefresh: isOnline,
      ),
    };
  }
}

class _RelatedArticle extends StatelessWidget {
  const _RelatedArticle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
    this.focusNode,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      focusNode: focusNode,
      semanticsLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TypographyTokens.titleMedium().copyWith(
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodySmall(),
          ),
        ],
      ),
    );
  }
}
