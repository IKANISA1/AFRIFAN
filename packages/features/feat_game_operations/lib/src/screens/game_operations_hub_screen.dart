import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/game_operations_ui.dart';

class GameOperationsHubScreen extends StatelessWidget {
  const GameOperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(
        context,
        l10n.gameOperationsTitle,
        fallbackPath: '/settings',
      ),
      scrollable: false,
      child: ListView(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        children: [
          Text(
            l10n.gameOperationsSubtitle,
            style: TypographyTokens.bodyLarge(
              context.afriSemanticColors.secondaryText,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          AfriListRow(
            key: const ValueKey<String>('game-operations-my-tvs-action'),
            icon: AfriIcons.live,
            title: l10n.gameMyTvsTitle,
            subtitle: l10n.gameMyTvsSubtitle,
            onTap: () => context.push('/my-tvs'),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriListRow(
            key: const ValueKey<String>('game-operations-managed-games-action'),
            icon: AfriIcons.admin,
            title: l10n.gameManagedGamesTitle,
            subtitle: l10n.gameManagedGamesSubtitle,
            onTap: () => context.push('/game-operations/sessions'),
          ),
        ],
      ),
    );
  }
}
