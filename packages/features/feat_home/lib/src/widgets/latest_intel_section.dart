import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/home_content_repository.dart';

/// Latest Intel section -- horizontal scrolling news/article cards.
///
/// Fetches published articles from `news_articles` and renders
/// image-first cards. Falls back to gradient when no image_url is set.
/// Following the "No-Line" rule -- no dividers, spacing-based separation.
class LatestIntelSection extends ConsumerStatefulWidget {
  const LatestIntelSection({super.key});

  @override
  ConsumerState<LatestIntelSection> createState() => _LatestIntelSectionState();
}

class _LatestIntelSectionState extends ConsumerState<LatestIntelSection> {
  LatestIntelSnapshot _snapshot = const LatestIntelSnapshot();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadArticles());
  }

  Future<void> _loadArticles() async {
    try {
      final snapshot = await ref
          .read(latestIntelRepositoryProvider)
          .loadPublishedArticles();

      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'LatestIntelSection',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (mounted) {
        setState(() {
          _snapshot = const LatestIntelSnapshot(
            status: LatestIntelStatus.error,
            message:
                'Latest Intel is temporarily unavailable. Pull to refresh.',
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _snapshot.status == LatestIntelStatus.empty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AfriSectionHeader(title: 'News', subtitle: 'Latest club updates'),
        const SizedBox(height: SpacingTokens.spacing4),
        SizedBox(height: 260, child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonList();
    }

    switch (_snapshot.status) {
      case LatestIntelStatus.ready:
        return RepaintBoundary(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            separatorBuilder: (_, __) =>
                const SizedBox(width: SpacingTokens.spacing3),
            itemCount: _snapshot.articles.length,
            itemBuilder: (context, index) {
              final article = _snapshot.articles[index];
              return _IntelCard(article: article);
            },
          ),
        );
      case LatestIntelStatus.empty:
        return const SizedBox.shrink();
      case LatestIntelStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: GlassCard(
            animate: false,
            child: AfriErrorView(
              compact: true,
              message: _snapshot.message,
              onRetry: _loadArticles,
            ),
          ),
        );
    }
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      separatorBuilder: (_, __) =>
          const SizedBox(width: SpacingTokens.spacing3),
      itemCount: 3,
      itemBuilder: (_, __) => const _IntelCardSkeleton(),
    );
  }
}

class _IntelCard extends StatelessWidget {
  final Map<String, dynamic> article;

  const _IntelCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ColorTokens.clubAccent;
    final articleId = article['id']?.toString();
    final title = article['title']?.toString() ?? '';
    final subtitle = article['subtitle']?.toString() ?? '';
    final imageUrl = article['image_url']?.toString();

    return SizedBox(
      width: 216,
      child: AfriPressFeedback(
        onTap: articleId == null
            ? null
            : () => context.push('/news/$articleId'),
        semanticsLabel: title.isEmpty ? 'Latest Intel article' : title,
        semanticsHint: articleId == null ? null : 'Open article',
        tooltip: title.isEmpty ? 'Latest Intel article' : title,
        excludeChildSemantics: true,
        builder: (context, state) => ClipRRect(
          borderRadius: ShapeTokens.cardRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: ColorTokens.glassFill,
              borderRadius: ShapeTokens.cardRadius,
              border: state.isFocused
                  ? BorderTokens.focusAll(color: primaryColor, opacity: 0.70)
                  : BorderTokens.ghost(),
              boxShadow: state.isFocused || state.isHovered
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.14),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image area -- real photo or rich gradient fallback
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: 118,
                    width: double.infinity,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            cacheManager: AfriImageCacheManager.instance,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                _GradientFallback(primaryColor: primaryColor),
                            errorWidget: (_, __, ___) =>
                                _GradientFallback(primaryColor: primaryColor),
                          )
                        : _GradientFallback(primaryColor: primaryColor),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TypographyTokens.titleMedium(),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TypographyTokens.bodySmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient fallback used when the image URL is unavailable.
/// Atmospheric stadium-vibe gradient without decorative emoji or filler icons.
class _GradientFallback extends StatelessWidget {
  final Color primaryColor;

  const _GradientFallback({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ColorTokens.borrowedGradient(
          colors: [
            primaryColor.withValues(alpha: 0.35),
            ColorTokens.clubSecondary.withValues(alpha: 0.4),
            ColorTokens.surfaceContainerHigh,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Skeleton card for loading state.
class _IntelCardSkeleton extends StatelessWidget {
  const _IntelCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 216,
      child: ClipRRect(
        borderRadius: ShapeTokens.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            color: ColorTokens.glassFill,
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.ghost(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton
              Container(
                height: 118,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
              ),
              // Text skeletons
              Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 180,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
