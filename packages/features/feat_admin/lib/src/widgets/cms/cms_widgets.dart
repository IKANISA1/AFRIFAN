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
    return AfriInputField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      hint: hint,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.actionFocusNode,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final FocusNode? actionFocusNode;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    final heading = Text(
      title.toUpperCase(),
      style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.1),
    );
    final action = AfriTextIconButton(
      key: ValueKey<String>(
        'admin-cms-action-${actionLabel.toLowerCase().replaceAll(' ', '-')}',
      ),
      onPressed: onAction,
      icon: const Icon(AfriIcons.add, size: 18),
      label: Text(actionLabel),
      focusNode: actionFocusNode,
      style: AfriTextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: SpacingTokens.spacing2),
          action,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        action,
      ],
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
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final String toggleLabel;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    final tagList = Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing3,
                vertical: SpacingTokens.spacing1,
              ),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainerLow,
                borderRadius: ShapeTokens.buttonRadius,
              ),
              child: Text(tag, style: TypographyTokens.labelSmall()),
            ),
          )
          .toList(),
    );
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (largeText) ...[
            Text(
              title.toUpperCase(),
              style: TypographyTokens.titleLarge().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            tagList,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TypographyTokens.titleLarge().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Flexible(child: tagList),
              ],
            ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(subtitle, style: TypographyTokens.bodyMedium()),
          if (body != null && body!.trim().isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(body!, style: TypographyTokens.bodyMedium()),
          ],
          const SizedBox(height: SpacingTokens.spacing3),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: [
              AfriTextIconButton(
                onPressed: onEdit,
                icon: const Icon(AfriIcons.edit, size: 18),
                label: Text(context.afriL10n.adminCmsEdit),
                style: AfriTextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              AfriTextIconButton(
                onPressed: onToggle,
                icon: const Icon(AfriIcons.toggleOn, size: 18),
                label: Text(toggleLabel),
                style: AfriTextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
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
  final VoidCallback? onTogglePublish;

  @override
  Widget build(BuildContext context) {
    final title =
        article['title']?.toString() ?? context.afriL10n.adminCmsUntitled;
    final category =
        article['category']?.toString() ??
        context.afriL10n.adminCmsNewsFallback;
    final isPublished = article['is_published'] == true;
    final isFeatured = article['is_featured'] == true;
    final publishedAt = DateTime.tryParse(
      article['published_at']?.toString() ?? '',
    );
    final materialL10n = MaterialLocalizations.of(context);

    final statusLabel = isPublished
        ? context.afriL10n.adminCmsLive
        : context.afriL10n.adminCmsDraft;
    final localPublishedAt = publishedAt?.toLocal();
    final dateLabel = localPublishedAt == null
        ? context.afriL10n.adminCmsNotPublished
        : context.afriL10n.adminCmsPair(
            materialL10n.formatShortDate(localPublishedAt),
            materialL10n.formatTimeOfDay(
              TimeOfDay.fromDateTime(localPublishedAt),
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            ),
          );

    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    final status = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: isPublished
            ? ColorTokens.clubAccent.withValues(alpha: 0.15)
            : ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: Text(statusLabel, style: TypographyTokens.labelSmall()),
    );

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (largeText) ...[
            Text(
              title.toUpperCase(),
              style: TypographyTokens.titleLarge().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Align(alignment: Alignment.centerLeft, child: status),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TypographyTokens.titleLarge().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                status,
              ],
            ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            context.afriL10n.adminCmsArticleMeta(
              category.toUpperCase(),
              dateLabel,
              isFeatured ? '  •  ${context.afriL10n.adminCmsFeatured}' : '',
            ),
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AfriTextIconButton(
                key: ValueKey<String>(
                  'admin-cms-publish-${article['id'] ?? 'unknown'}',
                ),
                onPressed: onTogglePublish,
                icon: Icon(
                  isPublished ? AfriIcons.unpublished : AfriIcons.publish,
                  size: 18,
                ),
                label: Text(
                  isPublished
                      ? context.afriL10n.adminCmsUnpublish
                      : context.afriL10n.adminCmsPublish,
                ),
                style: AfriTextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
