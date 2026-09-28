import 'package:flutter/material.dart';

import '../club_config_scope.dart';
import '../runtime_branding.dart';
import '../team_identity.dart';
import '../tokens/chrome_tokens.dart';
import 'afri_team_card.dart';

/// The configured club's published crest. No generated replacement artwork.
class AfriBrandMark extends StatelessWidget {
  const AfriBrandMark({
    super.key,
    this.label,
    this.size = AfriChromeTokens.commandControlSize,
    this.semanticLabel,
  });
  final String? label;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: AfriTeamCrest(
      name: teamAssetFor(label ?? '') != null
          ? label!
          : ClubConfigScope.maybeOf(context)?.clubName ??
                RuntimeBranding.displayHomeTeamName,
      size: size,
    ),
  );
}
