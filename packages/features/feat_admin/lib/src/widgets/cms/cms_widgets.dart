part of '../../screens/cms_content_manager_screen.dart';

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.1),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}
class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: AfriEmptyView(
        compact: true,
        title: title,
        message: message,
        icon: AfriIcons.statusEmpty,
      ),
    );
  }
}
class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.onEdit,
    required this.onToggle,
    required this.toggleLabel,
    this.body,
  });

  final String title;
  final String subtitle;
  final String? body;
  final List<String> tags;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final String toggleLabel;

  @override
  Widget build(BuildContext context) {
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
                  style: TypographyTokens.titleLarge().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
              ),
              Wrap(
                spacing: SpacingTokens.spacing2,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing3,
                          vertical: SpacingTokens.spacing1,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTokens.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(tag, style: TypographyTokens.labelSmall()),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(subtitle, style: TypographyTokens.bodyMedium()),
          if (body != null && body!.trim().isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(body!, style: TypographyTokens.bodyMedium()),
          ],
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('EDIT'),
              ),
              TextButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.toggle_on_outlined, size: 18),
                label: Text(toggleLabel),
              ),
            ],
          ),
        ],
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
                  style: TypographyTokens.titleLarge().copyWith(
                    color: ColorTokens.onSurface,
                  ),
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
