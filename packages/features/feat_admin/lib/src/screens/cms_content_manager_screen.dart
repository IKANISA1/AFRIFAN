import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../repositories/admin_repository.dart';

class CmsContentManagerScreen extends ConsumerStatefulWidget {
  const CmsContentManagerScreen({super.key});

  @override
  ConsumerState<CmsContentManagerScreen> createState() =>
      _CmsContentManagerScreenState();
}

class _CmsContentManagerScreenState
    extends ConsumerState<CmsContentManagerScreen> {
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final articles = await repo.getNewsArticles();
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePublish(String articleId, bool currentlyPublished) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateNewsArticle(articleId, {
        'is_published': !currentlyPublished,
        if (!currentlyPublished)
          'published_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _loadArticles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  void _showCreateArticleDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ColorTokens.surfaceContainer,
        title: Text(
          'NEW ARTICLE',
          style: TypographyTokens.titleLarge(),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'Article title'),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: bodyController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Article body'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              ctx.pop();
              try {
                final repo = ref.read(adminRepositoryProvider);
                await repo.createNewsArticle(
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
                );
                await _loadArticles();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to create: $e')));
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'CONTENT MANAGER',
          style: TypographyTokens.titleLarge(),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _articles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No articles yet.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    ClaymorphicButton(
                      label: 'CREATE FIRST ARTICLE',
                      width: double.infinity,
                      onPressed: _showCreateArticleDialog,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadArticles,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  ..._articles.map(
                    (article) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: _ArticleCard(
                        article: article,
                        onTogglePublish: () => _togglePublish(
                          article['id'].toString(),
                          article['is_published'] == true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ClaymorphicButton(
                    label: 'ADD ARTICLE',
                    width: double.infinity,
                    onPressed: _showCreateArticleDialog,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTogglePublish});

  final Map<String, dynamic> article;
  final VoidCallback onTogglePublish;

  @override
  Widget build(BuildContext context) {
    final title = article['title']?.toString() ?? 'Untitled';
    final category = article['category']?.toString() ?? 'News';
    final isPublished = article['is_published'] == true;
    final isFeatured = article['is_featured'] == true;
    final publishedAt = DateTime.tryParse(
      article['published_at']?.toString() ?? '',
    );

    final statusLabel = isPublished ? 'LIVE' : 'DRAFT';
    final dateLabel = publishedAt != null
        ? DateFormat('dd MMM HH:mm').format(publishedAt)
        : 'Not published';

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TypographyTokens.titleLarge().copyWith(color: ColorTokens.onSurface),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: isPublished
                      ? ColorTokens.clubAccent.withValues(alpha: 0.15)
                      : ColorTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(statusLabel, style: TypographyTokens.labelSmall()),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${category.toUpperCase()}  •  $dateLabel${isFeatured ? '  •  FEATURED' : ''}',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onTogglePublish,
                icon: Icon(
                  isPublished
                      ? Icons.unpublished_rounded
                      : Icons.publish_rounded,
                  size: 18,
                ),
                label: Text(isPublished ? 'UNPUBLISH' : 'PUBLISH'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
