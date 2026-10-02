import 'package:club_data/club_data.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'club_collection_screens.dart';

/// An explicit club publication, independent from reward/redemption eligibility.
final clubPartnersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, id) async {
      final publicSource = ref.watch(gikundiroPublicClientProvider);
      if (publicSource != null) {
        final rows = await loadGikundiroPublicPartners(publicSource);
        return id == null
            ? rows
            : rows.where((row) => row['id'] == id).toList(growable: false);
      }
      final client = ref.watch(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      var query = client
          .from('club_partner_publications')
          .select(
            'id,name,category,description,logo_url,image_url,image_rights_approved,image_provenance_id,website_url',
          )
          .eq('club_id', scope.requiredClubId);
      if (id != null) query = query.eq('id', id);
      final rows = await query
          .order('sort_order', ascending: true)
          .limit(100)
          .timeout(const Duration(seconds: 12));
      return rows.map((row) => Map<String, dynamic>.from(row)).toList();
    });

class ClubPartnersScreen extends ConsumerWidget {
  const ClubPartnersScreen({super.key, this.partnerId});
  final String? partnerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.afriL10n;
    final state = ref.watch(clubPartnersProvider(partnerId));
    return ClubCollectionScaffold<Map<String, dynamic>>(
      title: l.clubPartnersTitle,
      state: state,
      emptyTitle: l.clubPartnersEmpty,
      emptyMessage: l.clubPartnersIntro,
      onRetry: () => ref.invalidate(clubPartnersProvider(partnerId)),
      itemBuilder: (context, row) => AfriEditorialCard(
        imageRightsApproved: row['image_rights_approved'] == true,
        imageProvenanceId: row['image_provenance_id']?.toString(),
        imageUrl:
            row['image_rights_approved'] == true &&
                row['image_provenance_id']?.toString().trim().isNotEmpty == true
            ? (_https(row['image_url']) ?? _https(row['logo_url']))?.toString()
            : null,
        imageLabel: row['name'].toString(),
        imageFit: _https(row['image_url']) != null
            ? BoxFit.cover
            : BoxFit.contain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row['category']?.toString() ?? '',
              style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              row['name'].toString(),
              style: TypographyTokens.headlineMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              row['description']?.toString() ?? '',
              style: TypographyTokens.bodyLarge(),
            ),
            if (_https(row['website_url']) != null) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              AfriButton(
                label: l.clubPartnerWebsite,
                variant: AfriButtonVariant.secondary,
                onTap: () async {
                  final opened = await launchUrl(
                    _https(row['website_url'])!,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && context.mounted) {
                    AfriToast.error(context, l.genericError);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Uri? _https(Object? raw) {
  final uri = Uri.tryParse(raw?.toString() ?? '');
  return uri?.scheme == 'https' && uri!.host.isNotEmpty && uri.userInfo.isEmpty
      ? uri
      : null;
}
