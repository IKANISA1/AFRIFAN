import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/home_content_repository.dart';

/// Latest Intel section -- image-first news cards that reflow for larger text.
///
/// Fetches published articles from `news_articles` and renders
/// image-first cards, with compact text when no approved image is published.
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
            notice: LatestIntelNotice.unavailable,
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
    final l10n = context.afriL10n;
    final expandedText =
        MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
        _snapshot.articles.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AfriSectionHeader(
          title: l10n.homeNewsTitle,
          subtitle: l10n.homeLatestUpdates,
          trailing: AfriButton(
            label: l10n.shopShowAll,
            variant: AfriButtonVariant.ghost,
            fullWidth: false,
            semanticsLabel: '${l10n.shopShowAll}: ${l10n.homeNewsTitle}',
            onTap: () => context.push('/club/news'),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        SizedBox(
          height:
              (expandedText || _snapshot.status == LatestIntelStatus.empty) &&
                  !_isLoading
              ? null
              : SpacingTokens.spacing20 * 3 + SpacingTokens.spacing5,
          child: _buildBody(context, expandedText: expandedText),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, {required bool expandedText}) {
    if (_isLoading) {
      return _buildSkeletonList();
    }

    switch (_snapshot.status) {
      case LatestIntelStatus.ready:
        if (expandedText) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = 0;
                  index < _snapshot.articles.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(height: SpacingTokens.spacing4),
                  _IntelCard(
                    article: _snapshot.articles[index],
                    expandedText: true,
                  ),
                ],
              ],
            ),
          );
        }
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
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.screenPadding,
          ),
          child: AfriListRow(
            icon: AfriIcons.article,
            title: context.afriL10n.homeNewsEmpty,
            onTap: () => context.push('/club/news'),
          ),
        );
      case LatestIntelStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: GlassCard(
            animate: false,
            child: AfriErrorView(
              compact: true,
              message: switch (_snapshot.notice) {
                LatestIntelNotice.unavailable =>
                  context.afriL10n.homeLatestUnavailable,
                LatestIntelNotice.unpublished || null => null,
              },
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
  final bool expandedText;

  const _IntelCard({required this.article, this.expandedText = false});

  @override
  Widget build(BuildContext context) {
    final articleId = article['id']?.toString();
    final title = article['title']?.toString() ?? '';
    final subtitle = article['subtitle']?.toString() ?? '';
    final imageUrl = article['image_url']?.toString();
    final imageProvenanceId =
        article['image_provenance_id']?.toString().trim() ?? '';
    final imageRightsApproved =
        article['image_rights_approved'] == true &&
        imageProvenanceId.isNotEmpty;
    return SizedBox(
      width: expandedText ? double.infinity : 248,
      child: AfriEditorialCard(
        lightSurface: true,
        imageRightsApproved: imageRightsApproved,
        imageProvenanceId: imageProvenanceId,
        imageUrl: imageRightsApproved ? imageUrl : null,
        imageLabel: title,
        imageAspectRatio: expandedText ? 16 / 10 : 2.1,
        semanticsLabel: title,
        onTap: articleId == null
            ? null
            : () => context.push('/club/news/$articleId'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: expandedText ? null : 2,
              overflow: expandedText ? null : TextOverflow.ellipsis,
              style: TypographyTokens.titleMedium(ColorTokens.discoveryInk),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                subtitle,
                maxLines: expandedText ? null : 2,
                overflow: expandedText ? null : TextOverflow.ellipsis,
                style: TypographyTokens.bodySmall(ColorTokens.discoveryInk),
              ),
            ],
          ],
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
      width:
          SpacingTokens.spacing20 * 2 +
          SpacingTokens.spacing12 +
          SpacingTokens.spacing2,
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
                height:
                    SpacingTokens.spacing20 +
                    SpacingTokens.spacing10 -
                    SpacingTokens.spacing1 / 2,
                decoration: BoxDecoration(
                  color: ColorTokens.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(ShapeTokens.radiusXl),
                    topRight: Radius.circular(ShapeTokens.radiusXl),
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
                      height: SpacingTokens.spacing4,
                      width:
                          SpacingTokens.spacing20 * 2 + SpacingTokens.spacing5,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusSm,
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Container(
                      height: SpacingTokens.spacing3,
                      width:
                          SpacingTokens.spacing20 +
                          SpacingTokens.spacing12 +
                          SpacingTokens.spacing3,
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusSm,
                        ),
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
