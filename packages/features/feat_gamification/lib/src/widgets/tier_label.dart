import 'package:core_l10n/core_l10n.dart';

/// Localized presentation of known tiers; unknown server labels stay intact.
String fanTierLabel(AfriLocalizations l10n, String tier) =>
    switch (tier.trim().toLowerCase()) {
      'gold' => l10n.gameTierGold,
      'silver' => l10n.gameTierSilver,
      'bronze' => l10n.gameTierBronze,
      'imena' => l10n.gameTierImena,
      'supporter' => l10n.gameTierSupporter,
      'member' => l10n.gameTierMember,
      'ultra' => l10n.gameTierUltra,
      'legend' => l10n.gameTierLegend,
      'fan' => l10n.gameTierFan,
      _ => tier,
    };
