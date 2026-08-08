import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../controllers/game_operations_controllers.dart';
import '../game_operations_providers.dart';
import '../models/game_operations_models.dart';
import '../widgets/game_operations_ui.dart';

class ManagedGamesScreen extends ConsumerWidget {
  const ManagedGamesScreen({super.key, this.autofocusPlanAction = false});

  final bool autofocusPlanAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(managedGamesControllerProvider);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(
        context,
        l10n.gameManagedGamesTitle,
        titleRevision:
            '${state.status.name}-${state.failure?.kind.name ?? 'none'}',
      ),
      scrollable: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: ValueKey<String>(
                  'managed-games-subtitle-${state.status.name}-'
                  '${state.failure?.kind.name ?? 'none'}',
                ),
                child: Text(
                  key: const ValueKey<String>('managed-games-subtitle'),
                  l10n.gameManagedGamesSubtitle,
                  style: TypographyTokens.bodyMedium(
                    context.afriSemanticColors.secondaryText,
                  ),
                ),
              ),
              if (state.status == GameOperationsLoadStatus.loading &&
                  state.inventory != null) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                AfriInlineValidation(
                  key: const ValueKey<String>('managed-games-syncing-warning'),
                  message: l10n.gameManagedGamesRefreshing,
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing5),
              Expanded(child: _body(context, ref, state)),
              if (state.inventory?.canPlan == true) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                AfriButton(
                  key: const ValueKey<String>('managed-games-plan'),
                  label: l10n.gamePlanGame,
                  icon: AfriIcons.add,
                  enabled: state.canPlanSession,
                  autofocus: autofocusPlanAction,
                  onTap: () => context.push('/game-operations/sessions/new'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ManagedGamesState state) {
    final controller = ref.read(managedGamesControllerProvider.notifier);
    if (state.status == GameOperationsLoadStatus.loading &&
        state.inventory == null) {
      return AfriStateView.loading(
        title: context.afriL10n.gameManagedGamesLoading,
        message: context.afriL10n.gameManagedGamesSubtitle,
      );
    }
    if (state.status == GameOperationsLoadStatus.failure &&
        state.inventory == null) {
      return gameOperationsFailureView(
        context,
        state.failure,
        controller.load,
        offlineDescription:
            context.afriL10n.gameOrganizerOperationsOfflineDescription,
      );
    }
    final sessions = state.inventory?.sessions ?? const <ManagedGameSession>[];
    if (sessions.isEmpty) {
      return AfriStateView.empty(
        title: context.afriL10n.gameNoManagedGames,
        message: context.afriL10n.gameNoManagedGamesDescription,
        icon: AfriIcons.live,
      );
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AfriRefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const ValueKey<String>('managed-games-list'),
        itemCount: sessions.length + (state.failure == null ? 0 : 1),
        separatorBuilder: (_, __) =>
            const SizedBox(height: SpacingTokens.spacing3),
        itemBuilder: (context, index) {
          if (state.failure != null && index == 0) {
            return AfriSurfaceCard(
              key: const ValueKey<String>('managed-games-retained-warning'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AfriInlineValidation(
                    tone: AfriInlineValidationTone.warning,
                    message: context.afriL10n.gameManagedGamesStale,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    key: const ValueKey<String>(
                      'managed-games-refresh-retained',
                    ),
                    label: context.afriL10n.gameRefresh,
                    icon: AfriIcons.refresh,
                    variant: AfriButtonVariant.outline,
                    onTap: controller.load,
                  ),
                ],
              ),
            );
          }
          final sessionIndex = index - (state.failure == null ? 0 : 1);
          final session = sessions[sessionIndex];
          final start = session.scheduledStartAt == null
              ? null
              : DateFormat.yMMMd(
                  locale,
                ).add_jm().format(session.scheduledStartAt!.toLocal());
          final subtitle = [
            localizedGamePhase(context.afriL10n, session.phase),
            if (start != null) start,
            localizedEligibility(context.afriL10n, session.eligibilityScope),
          ].join(' · ');
          final onTap = state.canUseInventory
              ? () => context.push('/game-operations/sessions/${session.id}')
              : null;
          if (MediaQuery.textScalerOf(context).scale(1) >= 1.8) {
            return AfriSurfaceCard(
              key: ValueKey<String>('managed-game-session-${session.id}'),
              semanticsLabel: '${session.title}. $subtitle',
              enabled: state.canUseInventory,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AfriIcons.live,
                        color: context.afriSemanticColors.accent,
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: Text(
                          session.title,
                          style: TypographyTokens.titleMedium(
                            context.afriSemanticColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriStatusChip(
                    label: localizedGamePhase(context.afriL10n, session.phase),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    subtitle,
                    style: TypographyTokens.bodySmall(
                      context.afriSemanticColors.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          }
          return AfriListRow(
            key: ValueKey<String>('managed-game-session-${session.id}'),
            icon: AfriIcons.live,
            title: session.title,
            subtitle: subtitle,
            trailing: AfriStatusChip(
              label: localizedGamePhase(context.afriL10n, session.phase),
            ),
            enabled: state.canUseInventory,
            onTap: onTap,
          );
        },
      ),
    );
  }
}
