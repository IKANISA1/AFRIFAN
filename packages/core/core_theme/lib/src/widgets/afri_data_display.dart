import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_governed_image.dart';
import 'afri_press_feedback.dart';
import 'afri_status_chip.dart';
import 'afri_surface_card.dart';

class AfriTableCellData {
  const AfriTableCellData({
    required this.label,
    required this.value,
    this.priority = 1,
    this.numeric = false,
  });

  final String label;
  final String value;
  final int priority;
  final bool numeric;
}

/// Compact, responsive table row with label-value fallback on narrow widths.
class AfriTableRow extends StatelessWidget {
  const AfriTableRow({
    required this.cells,
    this.onTap,
    this.selected = false,
    this.semanticLabel,
    super.key,
  });

  final List<AfriTableCellData> cells;
  final VoidCallback? onTap;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final visible = compact
            ? cells.where((cell) => cell.priority <= 1).toList()
            : cells;
        final label =
            semanticLabel ??
            visible.map((cell) => '${cell.label}: ${cell.value}').join(', ');
        final content = compact
            ? Wrap(
                spacing: SpacingTokens.spacing4,
                runSpacing: SpacingTokens.spacing2,
                children: visible
                    .map(
                      (cell) => Semantics(
                        label: '${cell.label}: ${cell.value}',
                        child: Text(
                          '${cell.label}: ${cell.value}',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ),
                    )
                    .toList(),
              )
            : Row(
                children: visible
                    .map(
                      (cell) => Expanded(
                        child: Text(
                          cell.value,
                          textAlign: cell.numeric
                              ? TextAlign.end
                              : TextAlign.start,
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ),
                    )
                    .toList(),
              );
        return AfriPressFeedback(
          onTap: onTap,
          semanticsLabel: label,
          tooltip: onTap == null ? null : label,
          excludeChildSemantics: onTap != null,
          builder: (context, state) => AfriSurfaceCard(
            backgroundColor: selected
                ? ColorTokens.primaryTint(0.12)
                : ColorTokens.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing4,
              vertical: SpacingTokens.spacing3,
            ),
            child: content,
          ),
        );
      },
    );
  }
}

class AfriAvatar extends StatelessWidget {
  const AfriAvatar({
    required this.semanticLabel,
    required this.initials,
    this.image,
    this.provenanceId,
    this.rightsApproved = false,
    this.size = SizeTokens.touchTargetMin,
    super.key,
  }) : assert(size > 0);

  final String semanticLabel;
  final String initials;
  final ImageProvider? image;
  final String? provenanceId;
  final bool rightsApproved;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasApprovedImage =
        image != null &&
        rightsApproved &&
        provenanceId?.trim().isNotEmpty == true;
    if (hasApprovedImage) {
      return ClipOval(
        child: AfriGovernedImage(
          image: image!,
          width: size,
          height: size,
          semanticLabel: semanticLabel,
          provenanceId: provenanceId!.trim(),
          rightsApproved: true,
          borderRadius: ShapeTokens.radiusFull,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      );
    }

    final normalized = initials
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return Semantics(
      image: true,
      label: '$semanticLabel avatar',
      child: ExcludeSemantics(
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: ColorTokens.surfaceContainerHigh,
          foregroundColor: ColorTokens.onSurface,
          child: Text(
            normalized.isEmpty ? '?' : normalized,
            style: TypographyTokens.titleMedium(),
          ),
        ),
      ),
    );
  }
}

enum AfriBadgeKind { identity, achievement, verification }

class AfriBadge extends StatelessWidget {
  const AfriBadge({
    required this.label,
    this.kind = AfriBadgeKind.achievement,
    this.icon,
    super.key,
  });

  final String label;
  final AfriBadgeKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = switch (kind) {
      AfriBadgeKind.identity => AfriStatusTone.info,
      AfriBadgeKind.achievement => AfriStatusTone.warning,
      AfriBadgeKind.verification => AfriStatusTone.success,
    };
    final resolvedIcon =
        icon ??
        switch (kind) {
          AfriBadgeKind.identity => AfriIcons.members,
          AfriBadgeKind.achievement => AfriIcons.badge,
          AfriBadgeKind.verification => AfriIcons.verified,
        };
    return AfriStatusChip(label: label, icon: resolvedIcon, tone: tone);
  }
}

class AfriTimelineEntry {
  const AfriTimelineEntry({
    required this.title,
    required this.timestamp,
    this.description,
    this.tone = AfriStatusTone.neutral,
  });

  final String title;
  final String timestamp;
  final String? description;
  final AfriStatusTone tone;
}

class AfriTimeline extends StatelessWidget {
  const AfriTimeline({required this.entries, super.key});

  final List<AfriTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AfriSurfaceCard(child: Text('No activity yet'));
    }
    return Semantics(
      container: true,
      label: 'Timeline with ${entries.length} events',
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++)
            _TimelineRow(
              entry: entries[index],
              isLast: index == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final AfriTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.tone) {
      AfriStatusTone.success => ColorTokens.success,
      AfriStatusTone.warning => ColorTokens.warning,
      AfriStatusTone.error => ColorTokens.error,
      AfriStatusTone.info => ColorTokens.info,
      AfriStatusTone.live => ColorTokens.primaryContainer,
      AfriStatusTone.neutral => ColorTokens.onSurfaceVariant,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AfriComponentSizes.timelineRailWidth,
          child: Column(
            children: [
              Container(
                width: AfriComponentSizes.timelineMarker,
                height: AfriComponentSizes.timelineMarker,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              if (!isLast)
                Container(
                  width: AfriComponentSizes.timelineStemWidth,
                  height: AfriComponentSizes.timelineStemHeight,
                  color: ColorTokens.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: TypographyTokens.titleSmall()),
                Text(
                  entry.timestamp,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
                if (entry.description?.trim().isNotEmpty == true)
                  Text(
                    entry.description!.trim(),
                    style: TypographyTokens.bodySmall(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AfriReceiptLine {
  const AfriReceiptLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;
}

class AfriReceipt extends StatelessWidget {
  const AfriReceipt({
    required this.title,
    required this.lines,
    required this.totalLabel,
    required this.totalValue,
    this.status,
    super.key,
  });

  final String title;
  final List<AfriReceiptLine> lines;
  final String totalLabel;
  final String totalValue;
  final AfriStatusChip? status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [
        '$title receipt',
        ...lines.map((line) => '${line.label}: ${line.value}'),
        '$totalLabel: $totalValue',
      ].join('. '),
      child: AfriSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: TypographyTokens.titleLarge()),
                ),
                if (status != null) status!,
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
                child: _ReceiptRow(
                  label: line.label,
                  value: line.value,
                  emphasized: line.emphasized,
                ),
              ),
            const Divider(),
            _ReceiptRow(label: totalLabel, value: totalValue, emphasized: true),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    required this.emphasized,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? TypographyTokens.titleMedium()
        : TypographyTokens.bodyMedium();
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: SpacingTokens.spacing4),
        Text(value, style: style, textAlign: TextAlign.end),
      ],
    );
  }
}

class AfriActivityItem extends StatelessWidget {
  const AfriActivityItem({
    required this.title,
    required this.timestamp,
    this.subtitle,
    this.icon = AfriIcons.history,
    this.status,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String timestamp;
  final String? subtitle;
  final IconData icon;
  final AfriStatusChip? status;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AfriPressFeedback(
      enabled: enabled,
      onTap: onTap,
      semanticsLabel: '$title. $timestamp',
      tooltip: onTap == null ? null : title,
      builder: (context, state) => Opacity(
        opacity: enabled ? 1 : 0.48,
        child: AfriSurfaceCard(
          padding: const EdgeInsets.all(SpacingTokens.spacing4),
          child: Row(
            children: [
              Icon(icon, color: ColorTokens.onSurfaceVariant),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TypographyTokens.titleSmall()),
                    if (subtitle?.trim().isNotEmpty == true)
                      Text(
                        subtitle!.trim(),
                        style: TypographyTokens.bodySmall(),
                      ),
                    Text(
                      timestamp,
                      style: TypographyTokens.labelSmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (status != null) status!,
            ],
          ),
        ),
      ),
    );
  }
}
