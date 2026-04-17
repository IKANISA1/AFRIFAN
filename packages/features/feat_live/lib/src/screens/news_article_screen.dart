import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:core_utils/core_utils.dart';

class NewsArticleScreen extends ConsumerStatefulWidget {
  const NewsArticleScreen({required this.articleId, super.key});

  final String articleId;

  @override
  ConsumerState<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends ConsumerState<NewsArticleScreen> {
  static const _preferredNewsTable = 'news_articles';
  static const _fallbackNewsTable = 'news_articles';

  Map<String, dynamic>? _article;
  List<Map<String, dynamic>> _related = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      final newsTable = await _resolveNewsTable(client);
      var articleQuery = client.from(newsTable).select().eq('id', widget.articleId);
      articleQuery = resolver.apply(articleQuery, scope);
      final article = await articleQuery.maybeSingle();

      if (article == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Article not found';
          });
        }
        return;
      }

      var relatedQuery = client
          .from(newsTable)
          .select('id, title, subtitle')
          .eq('is_published', true)
          .neq('id', widget.articleId);
      relatedQuery = resolver.apply(relatedQuery, scope);
      final related = await relatedQuery
          .order('sort_order', ascending: true)
          .limit(2);

      if (!mounted) return;

      setState(() {
        _article = Map<String, dynamic>.from(article);
        _related = List<Map<String, dynamic>>.from(related);
        _loading = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn('NewsArticleScreen', 'Operation failed (non-critical).', error, stackTrace);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load article.';
        });
      }
    }
  }

  Future<String> _resolveNewsTable(SupabaseClient client) async {
    for (final table in const [_preferredNewsTable, _fallbackNewsTable]) {
      try {
        await client.from(table).select('id').limit(1);
        return table;
      } on PostgrestException catch (error) {
        if (!_isMissingTable(error) || table == _fallbackNewsTable) {
          rethrow;
        }
      }
    }

    return _fallbackNewsTable;
  }

  bool _isMissingTable(PostgrestException error) {
    return error.code == 'PGRST205';
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final title = article?['title']?.toString() ?? 'Article';
    final subtitle = article?['subtitle']?.toString() ?? 'Club News';
    final category = article?['category']?.toString() ?? 'CLUB NEWS';
    final imageUrl = article?['image_url']?.toString();
    final content =
        article?['body']?.toString() ??
        article?['content']?.toString() ??
        subtitle;
    final createdAt = article?['created_at']?.toString() ?? '';

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: _loading
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriSkeletonList(),
              ),
            )
          : _error != null || article == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AfriIcons.article,
                      size: 56,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(_error ?? 'Article unavailable'),
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriButton(
                      label: 'Back',
                      onTap: () => context.pop(),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: ColorTokens.background,
                  leading: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(AfriIcons.back),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: imageUrl != null && imageUrl.isNotEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _ArticleHeroFallback(category: category),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      ColorTokens.background,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _ArticleHeroFallback(category: category),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AfriStatusChip(
                          label: category,
                          tone: AfriStatusTone.info,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Text(
                          title,
                          style: TypographyTokens.headlineLarge().copyWith(
                            color: ColorTokens.onSurface,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          'Club News  ·  ${createdAt.isEmpty ? 'Today' : createdAt.split('T').first}  ·  Media Desk',
                          style: TypographyTokens.bodySmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                        Text(
                          content,
                          style: TypographyTokens.bodyLarge().copyWith(
                            height: 1.6,
                          ),
                        ),
                        if (_related.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.spacing8),
                          const AfriSectionHeader(
                            title: 'Related intel',
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          ..._related.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SpacingTokens.spacing3,
                              ),
                              child: _RelatedArticle(
                                title: entry['title']?.toString() ?? 'Story',
                                subtitle: entry['subtitle']?.toString() ?? '',
                                onTap: () =>
                                    context.push('/news/${entry['id']}'),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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

class _RelatedArticle extends StatelessWidget {
  const _RelatedArticle({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
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
