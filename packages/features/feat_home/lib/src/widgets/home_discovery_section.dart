import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repositories/home_discovery_repository.dart';

class HomeDiscoverySection extends ConsumerWidget {
  const HomeDiscoverySection({super.key, required this.kind});
  final HomeDiscoveryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kind == HomeDiscoveryKind.predictions &&
        !ref.watch(featureConfigServiceProvider).isRouteAvailable('/predict')) {
      return const SizedBox.shrink();
    }
    final l = context.afriL10n;
    final (title, route, empty, icon) = switch (kind) {
      HomeDiscoveryKind.predictions => (
        l.homeActivePredictions,
        '/predict',
        l.homePredictionsEmpty,
        AfriIcons.predict,
      ),
      HomeDiscoveryKind.partners => (
        l.clubPartnersTitle,
        '/club/partners',
        l.homePartnersEmpty,
        AfriIcons.business,
      ),
      HomeDiscoveryKind.fanClubs => (
        l.fanClubsTitle,
        '/fan-clubs',
        l.homeFanClubsEmpty,
        AfriIcons.groups,
      ),
    };
    final state = ref.watch(homeDiscoveryProvider(kind));
    if (state.hasValue && state.value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: SpacingTokens.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriSectionHeader(
            title: title,
            trailing: AfriButton(
              label: l.shopShowAll,
              variant: AfriButtonVariant.ghost,
              fullWidth: false,
              semanticsLabel: '${l.shopShowAll}: $title',
              onTap: () => context.push(route),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.screenPadding,
            ),
            child: state.when(
              loading: () => const AfriSkeletonList(itemCount: 1),
              error: (_, __) => AfriListRow(
                icon: AfriIcons.refresh,
                title: l.homeDiscoveryUnavailable,
                subtitle: l.retry,
                onTap: () => ref.invalidate(homeDiscoveryProvider(kind)),
              ),
              data: (rows) => rows.isEmpty
                  ? AfriListRow(
                      icon: icon,
                      title: empty,
                      onTap: () => context.push(route),
                    )
                  : Column(
                      children: [
                        for (final row in rows.take(2)) ...[
                          _card(context, row, route),
                          const SizedBox(height: SpacingTokens.spacing3),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> row, String route) {
    final l = context.afriL10n;
    if (kind == HomeDiscoveryKind.predictions) {
      final kickoff = DateTime.tryParse('${row['kickoff_at']}')?.toLocal();
      final material = MaterialLocalizations.of(context);
      return AfriFixtureCard(
        lightSurface: true,
        homeTeam: '${row['home_team']}',
        awayTeam: '${row['away_team']}',
        homeCrest: row['home_crest'] as String?,
        awayCrest: row['away_crest'] as String?,
        subtitle: [
          row['competition']?.toString() ?? '',
          if (kickoff != null)
            '${material.formatMediumDate(kickoff)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(kickoff), alwaysUse24HourFormat: true)}',
        ].where((part) => part.isNotEmpty).join('\n'),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.predictIntro,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(ColorTokens.discoveryInk),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriButton(
              key: ValueKey('home-predict-${row['id']}'),
              label: l.homePredictAction,
              onTap: () => context.go(route),
            ),
          ],
        ),
        onTap: () => context.go(route),
      );
    }
    final partner = kind == HomeDiscoveryKind.partners;
    final approved =
        row['image_rights_approved'] == true &&
        row['image_provenance_id']?.toString().trim().isNotEmpty == true;
    final photo = partner
        ? (approved ? row['image_url'] ?? row['logo_url'] : null)
        : row['banner_image_url'];
    final title = row['name']?.toString() ?? '';
    final subtitle = partner
        ? row['category']?.toString() ?? ''
        : l.fanClubRegionMembers(
            row['region']?.toString() ?? '',
            row['member_count_label']?.toString() ??
                l.fanClubMembersValue('${row['member_count'] ?? 0}'),
          );
    return AfriEditorialCard(
      lightSurface: true,
      imageUrl: photo?.toString(),
      imageRightsApproved: partner ? approved : photo != null,
      imageProvenanceId: partner
          ? row['image_provenance_id']?.toString()
          : 'published-fan-club:${row["id"]}',
      imageLabel: title,
      imageFit: partner && row['image_url'] == null
          ? BoxFit.contain
          : BoxFit.cover,
      semanticsLabel: title,
      onTap: () => context.push(
        Uri(
          path: route,
          queryParameters: {partner ? 'partner' : 'club': row['id'].toString()},
        ).toString(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TypographyTokens.headlineMedium(ColorTokens.discoveryInk),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            subtitle,
            style: TypographyTokens.bodySmall(ColorTokens.discoveryInk),
          ),
        ],
      ),
    );
  }
}
