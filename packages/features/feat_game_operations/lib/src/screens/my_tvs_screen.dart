import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/game_operations_controllers.dart';
import '../game_operations_providers.dart';
import '../models/game_operations_models.dart';
import '../widgets/game_operations_ui.dart';

class MyTvsScreen extends ConsumerWidget {
  const MyTvsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.afriL10n;
    final state = ref.watch(displayInventoryControllerProvider);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(context, l10n.gameMyTvsTitle),
      scrollable: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.gameMyTvsSubtitle,
                style: TypographyTokens.bodyMedium(
                  context.afriSemanticColors.secondaryText,
                ),
              ),
              if (state.status == GameOperationsLoadStatus.loading &&
                  state.inventory != null) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                AfriInlineValidation(
                  key: const ValueKey<String>('my-tvs-syncing-warning'),
                  message: l10n.gameTvInventoryRefreshing,
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing5),
              Expanded(child: _body(context, ref, state)),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriButton(
                key: const ValueKey<String>('my-tvs-pair'),
                label: l10n.gameAddTv,
                icon: AfriIcons.add,
                enabled: state.canStartPairingOperation,
                onTap: () => context.push('/my-tvs/pair'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    DisplayInventoryState state,
  ) {
    final controller = ref.read(displayInventoryControllerProvider.notifier);
    if (state.status == GameOperationsLoadStatus.loading &&
        state.inventory == null) {
      return AfriStateView.loading(
        title: context.afriL10n.gameTvInventoryLoading,
        message: context.afriL10n.gameOperationsSubtitle,
      );
    }
    if (state.status == GameOperationsLoadStatus.failure &&
        state.inventory == null) {
      return gameOperationsFailureView(context, state.failure, controller.load);
    }
    final displays = state.inventory?.displays ?? const <OwnedDisplay>[];
    if (displays.isEmpty) {
      return AfriStateView.empty(
        title: context.afriL10n.gameNoTvs,
        message: context.afriL10n.gameNoTvsDescription,
        icon: AfriIcons.live,
      );
    }
    return AfriRefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        key: const ValueKey<String>('my-tvs-list'),
        itemCount: displays.length + (state.failure == null ? 0 : 1),
        separatorBuilder: (_, __) =>
            const SizedBox(height: SpacingTokens.spacing3),
        itemBuilder: (context, index) {
          if (state.failure != null && index == 0) {
            return AfriSurfaceCard(
              key: const ValueKey<String>('my-tvs-retained-warning'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AfriInlineValidation(
                    tone: AfriInlineValidationTone.warning,
                    message: context.afriL10n.gameTvInventoryStale,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    key: const ValueKey<String>('my-tvs-refresh-retained'),
                    label: context.afriL10n.gameRefresh,
                    icon: AfriIcons.refresh,
                    variant: AfriButtonVariant.outline,
                    onTap: controller.load,
                  ),
                ],
              ),
            );
          }
          final displayIndex = index - (state.failure == null ? 0 : 1);
          final display = displays[displayIndex];
          final status = localizedDisplayHealth(
            context.afriL10n,
            display.health,
          );
          return AfriSurfaceCard(
            key: ValueKey<String>('my-tv-display-${display.id}'),
            semanticsLabel: display.name,
            onTap: () => context.push('/my-tvs/${display.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        display.name,
                        style: TypographyTokens.titleMedium(
                          context.afriSemanticColors.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    AfriStatusChip(label: status),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                GameOperationsInfoRow(
                  label: context.afriL10n.gameTvScope,
                  value: localizedDisplayScope(
                    context.afriL10n,
                    display.scopeType,
                  ),
                ),
                GameOperationsInfoRow(
                  label: context.afriL10n.gameTvLastSeen,
                  value: formattedDisplayLastSeen(context, display.lastSeenAt),
                ),
                GameOperationsInfoRow(
                  label: context.afriL10n.gameTvAppVersion,
                  value:
                      display.appVersion ?? context.afriL10n.gameTvNotReported,
                ),
                GameOperationsInfoRow(
                  label: context.afriL10n.gameTvCapabilities,
                  value: formattedDisplayCapabilities(
                    context,
                    display.capabilities,
                  ),
                ),
                GameOperationsInfoRow(
                  label: context.afriL10n.gameTvAssignedGame,
                  value: formattedAssignedSession(context, display),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
