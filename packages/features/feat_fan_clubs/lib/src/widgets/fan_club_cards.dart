import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

import '../official_fanclub_register.dart';

/// One directory entry, one action. Membership workflow stays server-side.
class FanClubCard extends StatelessWidget {
  const FanClubCard({super.key, required this.club});

  final Map<String, dynamic> club;

  @override
  Widget build(BuildContext context) {
    final name =
        club['name']?.toString() ?? context.afriL10n.fanClubFallbackName;
    final description = club['description']?.toString().trim() ?? '';
    final members = fanclubMemberLabel(club);
    final region =
        club['region']?.toString() ?? context.afriL10n.fanClubUnknownRegion;
    return AfriEditorialCard(
      imageRightsApproved: club['banner_image_url'] != null,
      imageProvenanceId: 'published-fan-club:${club["id"]}',
      imageUrl: club['banner_image_url']?.toString(),
      imageLabel: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: TypographyTokens.headlineMedium()),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              description,
              style: TypographyTokens.bodyLarge(ColorTokens.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            context.afriL10n.fanClubRegionMembers(
              region,
              num.tryParse(members) == null
                  ? members
                  : context.afriL10n.fanClubMembersValue(members),
            ),
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
