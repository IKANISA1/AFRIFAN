import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/game_operations_controllers.dart';
import '../game_operations_providers.dart';
import '../models/game_operations_models.dart';
import '../widgets/game_operations_ui.dart';

class TvDetailScreen extends ConsumerStatefulWidget {
  const TvDetailScreen({required this.displayId, super.key});

  final String displayId;

  @override
  ConsumerState<TvDetailScreen> createState() => _TvDetailScreenState();
}

class _TvDetailScreenState extends ConsumerState<TvDetailScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _initializedDisplayId;
  String _scopeKey = 'home';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initialize(OwnedDisplay display) {
    if (_initializedDisplayId == display.id) return;
    _initializedDisplayId = display.id;
    _nameController.text = display.name;
    _scopeKey = display.scopeType == 'venue'
        ? 'venue:${display.venueId}'
        : 'home';
  }

  void _handleFormChanged(String _) => setState(() {});

  List<OwnedDisplayScopeOption> _availableScopes(
    OwnedDisplayInventory inventory,
  ) {
    return List<OwnedDisplayScopeOption>.of(inventory.scopeOptions);
  }

  bool _hasValidChange(
    OwnedDisplay display,
    OwnedDisplayScopeOption? selectedScope,
  ) {
    final name = _nameController.text.trim();
    if (name.length < 2 || selectedScope == null) return false;
    return name != display.name ||
        selectedScope.scopeType != display.scopeType ||
        selectedScope.venueId != display.venueId;
  }

  Future<void> _save(
    OwnedDisplay display,
    OwnedDisplayScopeOption selectedScope,
  ) async {
    final name = _nameController.text.trim();
    if (name.length < 2) return;
    final changed =
        name != display.name ||
        selectedScope.scopeType != display.scopeType ||
        selectedScope.venueId != display.venueId;
    if (!changed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AfriAlertDialog(
        title: Text(context.afriL10n.gameSaveTvConfirmTitle),
        content: Text(context.afriL10n.gameSaveTvConfirmDescription),
        actions: [
          AfriButton(
            label: context.afriL10n.gameCancel,
            variant: AfriButtonVariant.ghost,
            fullWidth: false,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AfriButton(
            key: const ValueKey<String>('tv-detail-save-confirm'),
            label: context.afriL10n.gameSaveTvConfirmAction,
            fullWidth: false,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(displayInventoryControllerProvider.notifier)
        .update(
          displayId: display.id,
          displayName: name,
          scopeType: selectedScope.scopeType,
          venueId: selectedScope.venueId,
        );
  }

  Future<void> _confirmRevoke(OwnedDisplay display) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AfriAlertDialog(
        title: Text(context.afriL10n.gameRevokeTvConfirmTitle),
        content: Text(context.afriL10n.gameRevokeTvConfirmDescription),
        actions: [
          AfriButton(
            label: context.afriL10n.gameCancel,
            variant: AfriButtonVariant.ghost,
            fullWidth: false,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AfriButton(
            key: const ValueKey<String>('tv-detail-revoke-confirm'),
            label: context.afriL10n.gameRevokeTvConfirmAction,
            variant: AfriButtonVariant.destructive,
            fullWidth: false,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(displayInventoryControllerProvider.notifier)
        .revoke(display.id);
    if (success && mounted) context.go('/my-tvs');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final state = ref.watch(displayInventoryControllerProvider);
    final display = state.inventory?.displays
        .where((candidate) => candidate.id == widget.displayId)
        .firstOrNull;
    if (display != null) _initialize(display);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(
        context,
        l10n.gameTvDetailsTitle,
        fallbackPath: '/my-tvs',
      ),
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        child: _body(context, state, display),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    DisplayInventoryState state,
    OwnedDisplay? display,
  ) {
    final l10n = context.afriL10n;
    final controller = ref.read(displayInventoryControllerProvider.notifier);
    if (display == null && state.status == GameOperationsLoadStatus.loading) {
      return AfriStateView.loading(
        title: l10n.gameTvInventoryLoading,
        message: l10n.gameOperationsSubtitle,
      );
    }
    if (display == null && state.status == GameOperationsLoadStatus.failure) {
      return gameOperationsFailureView(context, state.failure, controller.load);
    }
    if (display == null) {
      return AfriStateView.empty(
        title: l10n.gameNoTvs,
        message: l10n.gameNoTvsDescription,
        icon: AfriIcons.live,
      );
    }
    final scopeOptions = _availableScopes(state.inventory!);
    final selectedScope = scopeOptions
        .where((option) => option.key == _scopeKey)
        .firstOrNull;
    final canManage = state.canManageDisplay;
    return ListView(
      children: [
        AfriSurfaceCard(
          child: Column(
            children: [
              GameOperationsInfoRow(
                label: l10n.gameTvHealth,
                value: localizedDisplayHealth(l10n, display.health),
              ),
              GameOperationsInfoRow(
                label: l10n.gameTvStatus,
                value: localizedPairingStatus(l10n, display.pairingStatus),
              ),
              GameOperationsInfoRow(
                label: l10n.gameTvAssignedGame,
                value: formattedAssignedSession(context, display),
              ),
              GameOperationsInfoRow(
                label: l10n.gameTvLastSeen,
                value: formattedDisplayLastSeen(context, display.lastSeenAt),
              ),
              GameOperationsInfoRow(
                label: l10n.gameTvAppVersion,
                value: display.appVersion ?? l10n.gameTvNotReported,
              ),
              GameOperationsInfoRow(
                label: l10n.gameTvCapabilities,
                value: formattedDisplayCapabilities(
                  context,
                  display.capabilities,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing5),
        AfriInputField(
          key: const ValueKey<String>('tv-detail-name'),
          controller: _nameController,
          label: l10n.gameTvName,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          enabled: canManage,
          onChanged: _handleFormChanged,
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriDropdownField<String>(
          key: const ValueKey<String>('tv-detail-scope'),
          initialValue: selectedScope?.key,
          label: l10n.gameTvAuthorizedScope,
          hint: l10n.gameNoAuthorizedTvScopes,
          enabled: canManage,
          items: scopeOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.key,
                  child: Text(
                    option.scopeType == 'home'
                        ? l10n.gameTvScopeHome
                        : option.label,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) setState(() => _scopeKey = value);
          },
        ),
        if (selectedScope == null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriInlineValidation(
            tone: AfriInlineValidationTone.error,
            message: l10n.gameNoAuthorizedTvScopes,
          ),
        ],
        if (state.status == GameOperationsLoadStatus.loading) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriInlineValidation(
            key: const ValueKey<String>('tv-detail-syncing-warning'),
            message: l10n.gameTvInventoryRefreshing,
          ),
        ],
        if (state.failure != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          AfriInlineValidation(
            key: const ValueKey<String>('tv-detail-retained-warning'),
            tone: AfriInlineValidationTone.error,
            message: gameOperationsFailureDescription(l10n, state.failure!),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            key: const ValueKey<String>('tv-detail-refresh-after-failure'),
            label: l10n.gameRefresh,
            icon: AfriIcons.refresh,
            variant: AfriButtonVariant.outline,
            onTap: controller.load,
          ),
        ],
        const SizedBox(height: SpacingTokens.spacing5),
        AfriButton(
          key: const ValueKey<String>('tv-detail-save'),
          label: l10n.gameSaveTv,
          icon: AfriIcons.check,
          isLoading: state.mutating,
          enabled: canManage && _hasValidChange(display, selectedScope),
          labelMaxLines: 2,
          onTap: () => _save(display, selectedScope!),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        AfriButton(
          key: const ValueKey<String>('tv-detail-pairing'),
          label: l10n.gameRecoverTvAction,
          icon: AfriIcons.refresh,
          variant: AfriButtonVariant.outline,
          isLoading: state.mutating,
          enabled: canManage,
          labelMaxLines: 2,
          onTap: () => context.push(
            Uri(
              path: '/my-tvs/pair',
              queryParameters: <String, String>{'recoverDisplayId': display.id},
            ).toString(),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        AfriButton(
          key: const ValueKey<String>('tv-detail-revoke'),
          label: l10n.gameRevokeTv,
          icon: AfriIcons.delete,
          variant: AfriButtonVariant.destructive,
          enabled: canManage,
          labelMaxLines: 2,
          onTap: () => _confirmRevoke(display),
        ),
      ],
    );
  }
}
