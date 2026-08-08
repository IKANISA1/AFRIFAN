import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Notification preview card showing audience, title, and body.
class NotificationPreviewCard extends StatelessWidget {
  const NotificationPreviewCard({
    super.key,
    required this.audience,
    required this.title,
    required this.body,
  });

  final String audience;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.afriL10n.adminNotificationPreview,
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SpacingTokens.spacing4),
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerLow,
              borderRadius: ShapeTokens.inputRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audience.toUpperCase(),
                  style: TypographyTokens.labelSmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  title.isEmpty
                      ? context.afriL10n.adminNotificationTitleLabel
                      : title,
                  style: TypographyTokens.bodyLarge(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  body.isEmpty
                      ? context.afriL10n.adminNotificationPreviewBody
                      : body,
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single notification history item card.
class NotificationHistoryCard extends StatelessWidget {
  const NotificationHistoryCard({
    super.key,
    required this.title,
    required this.body,
    required this.status,
    this.date,
    this.metrics = '',
  });

  final String title;
  final String body;
  final String status;
  final DateTime? date;
  final String metrics;

  @override
  Widget build(BuildContext context) {
    final datePart = date == null
        ? ''
        : '  •  ${DateFormat('dd MMM HH:mm', Localizations.localeOf(context).toLanguageTag()).format(date!.toLocal())}';
    final statusLabel = switch (status) {
      'scheduled' => context.afriL10n.adminNotificationStatusScheduled,
      'sent' => context.afriL10n.adminNotificationStatusSent,
      'partial' => context.afriL10n.adminNotificationStatusPartial,
      'failed' => context.afriL10n.adminNotificationStatusFailed,
      _ => status.toUpperCase(),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TypographyTokens.titleLarge().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(body, style: TypographyTokens.bodyMedium()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              '$statusLabel$datePart$metrics',
              style: TypographyTokens.bodySmall(),
            ),
          ],
        ),
      ),
    );
  }
}
