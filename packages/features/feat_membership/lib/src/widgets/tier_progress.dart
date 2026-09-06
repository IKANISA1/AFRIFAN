import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// Explains the membership programme without deriving a tier from FET activity.
class TierProgress extends StatelessWidget {
  const TierProgress({super.key, this.qualification, this.currentFet});
  final Map<String, dynamic>? qualification;
  // Source compatibility only; a FET balance never determines qualification.
  final int? currentFet;

  @override
  Widget build(BuildContext context) => AfriSectionCard(
    title: context.afriL10n.membershipProgrammeTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.afriL10n.membershipProgrammeBody,
          style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (qualification?['available'] == true) ...[
          Text(
            context.afriL10n.membershipConfirmedTotal(
              (qualification?['confirmed_total_rwf'] as num?)?.toInt() ?? 0,
            ),
            style: TypographyTokens.titleLarge(),
          ),
          Text(
            context.afriL10n.membershipQualificationWindow,
            style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
          ),
          if (qualification?['remaining_rwf'] != null)
            Text(
              context.afriL10n.membershipRemainingTotal(
                (qualification?['remaining_rwf'] as num).toInt(),
                qualification?['next_title']?.toString() ?? '',
              ),
              style: TypographyTokens.bodyMedium(),
            ),
        ] else
          Text(
            context.afriL10n.membershipQualificationUnavailable,
            style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
          ),
      ],
    ),
  );
}
