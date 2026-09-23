import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'club_collection_screens.dart';

/// An explicit club publication, independent from reward/redemption eligibility.
final clubPartnersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, id) async {
      final client = ref.watch(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      var query = client
          .from('club_partner_publications')
          .select(
            'id,name,category,description,logo_url,image_rights_approved,image_provenance_id,website_url',
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
      header: state.valueOrNull?.isNotEmpty == true
          ? Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.sectionGap),
              child: Text(
                l.clubPartnersIntro,
                style: TypographyTokens.bodyLarge(),
              ),
            )
          : null,
      itemBuilder: (context, row) => AfriSectionCard(
        title: row['name'].toString(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (row['image_rights_approved'] == true &&
                row['image_provenance_id'] != null &&
                _https(row['logo_url']) != null)
              Image.network(
                row['logo_url'].toString(),
                height: 72,
                fit: BoxFit.contain,
                semanticLabel: row['name'].toString(),
                errorBuilder: (_, error, stack) => const SizedBox.shrink(),
              ),
            Text(
              row['category'].toString(),
              style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
            ),
            if (partnerId != null) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                row['description'].toString(),
                style: TypographyTokens.bodyLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              if (_https(row['website_url']) != null)
                AfriButton(
                  label: l.clubPartnerWebsite,
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
            ] else ...[
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                label: l.clubPartnerDetails,
                variant: AfriButtonVariant.secondary,
                onTap: () => context.push('/club/partners/${row['id']}'),
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
