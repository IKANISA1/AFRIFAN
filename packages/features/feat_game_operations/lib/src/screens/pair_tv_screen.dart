import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/game_operations_controllers.dart';
import '../game_operations_providers.dart';
import '../models/game_operations_models.dart';
import '../widgets/game_operations_ui.dart';

class PairTvScreen extends ConsumerStatefulWidget {
  const PairTvScreen({super.key, this.initialChallenge, this.recoverDisplayId});

  final String? initialChallenge;
  final String? recoverDisplayId;

  @override
  ConsumerState<PairTvScreen> createState() => _PairTvScreenState();
}

class _PairTvScreenState extends ConsumerState<PairTvScreen> {
  late final TextEditingController _challengeController;
  final TextEditingController _nameController = TextEditingController();
  String _scopeKey = 'home';
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _challengeController = TextEditingController(
      text: widget.initialChallenge?.trim().toUpperCase() ?? '',
    );
  }

  @override
  void dispose() {
    _challengeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  OwnedDisplayScopeOption? _selectedScope(
    List<OwnedDisplayScopeOption> options,
  ) {
    return options.where((option) => option.key == _scopeKey).firstOrNull ??
        options.firstOrNull;
  }

  void _handleFormChanged(String _) {
    setState(() => _validationMessage = null);
  }

  bool _formIsValid({
    required bool recoveryRequested,
    required OwnedDisplayScopeOption? selectedScope,
    required OwnedDisplay? recoveryDisplay,
  }) {
    if (_challengeController.text.trim().length != 8) return false;
    if (recoveryRequested) return recoveryDisplay != null;
    return _nameController.text.trim().length >= 2 && selectedScope != null;
  }

  Future<void> _pair(
    List<OwnedDisplayScopeOption> options,
    OwnedDisplay? recoveryDisplay,
  ) async {
    final challenge = _challengeController.text.trim().toUpperCase();
    if (recoveryDisplay != null) {
      if (challenge.length != 8) {
        setState(() {
          _validationMessage = context.afriL10n.gameTvFormInvalid;
        });
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AfriAlertDialog(
          title: Text(context.afriL10n.gameRecoverTvConfirmTitle),
          content: Text(
            context.afriL10n.gameRecoverTvConfirmDescription(
              recoveryDisplay.name,
            ),
          ),
          actions: [
            AfriButton(
              label: context.afriL10n.gameCancel,
              variant: AfriButtonVariant.ghost,
              fullWidth: false,
              onTap: () => Navigator.of(dialogContext).pop(false),
            ),
            AfriButton(
              key: const ValueKey<String>('recover-tv-confirm'),
              label: context.afriL10n.gameRecoverTvConfirmAction,
              fullWidth: false,
              onTap: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _validationMessage = null);
      final recovered = await ref
          .read(displayInventoryControllerProvider.notifier)
          .recover(displayId: recoveryDisplay.id, challenge: challenge);
      if (mounted && recovered) context.go('/my-tvs');
      return;
    }

    final name = _nameController.text.trim();
    final selectedScope = _selectedScope(options);
    if (challenge.length != 8 || name.length < 2 || selectedScope == null) {
      setState(() {
        _validationMessage = context.afriL10n.gameTvFormInvalid;
      });
      return;
    }
    setState(() => _validationMessage = null);
    final success = await ref
        .read(displayInventoryControllerProvider.notifier)
        .claim(
          challenge: challenge,
          displayName: name,
          scopeType: selectedScope.scopeType,
          venueId: selectedScope.venueId,
        );
    if (!mounted) return;
    if (success) {
      context.go('/my-tvs');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final state = ref.watch(displayInventoryControllerProvider);
    final controller = ref.read(displayInventoryControllerProvider.notifier);
    final options =
        state.inventory?.scopeOptions ?? const <OwnedDisplayScopeOption>[];
    final selectedScope = _selectedScope(options);
    final recoveryDisplay = state.inventory?.displays
        .where((display) => display.id == widget.recoverDisplayId)
        .firstOrNull;
    final recoveryRequested = widget.recoverDisplayId != null;
    final initialLoading =
        state.status == GameOperationsLoadStatus.loading &&
        state.inventory == null;
    final initialFailure =
        state.status == GameOperationsLoadStatus.failure &&
        state.inventory == null;
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: gameOperationsAppBar(
        context,
        recoveryRequested ? l10n.gameRecoverTvTitle : l10n.gamePairTvTitle,
        fallbackPath: '/my-tvs',
      ),
      scrollable: false,
      child: initialLoading
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: AfriStateView.loading(
                  title: l10n.gameTvInventoryLoading,
                  message: l10n.gameOperationsSubtitle,
                ),
              ),
            )
          : initialFailure
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: gameOperationsFailureView(
                  context,
                  state.failure,
                  controller.load,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              children: [
                Text(
                  recoveryRequested
                      ? l10n.gameRecoverTvDescription
                      : l10n.gamePairTvDescription,
                  style: TypographyTokens.bodyMedium(
                    context.afriSemanticColors.secondaryText,
                  ),
                ),
                if (recoveryDisplay != null) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriSurfaceCard(
                    key: const ValueKey<String>('recover-tv-display'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          recoveryDisplay.name,
                          style: TypographyTokens.titleMedium(
                            context.afriSemanticColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          l10n.gameRecoverTvCodeInstruction,
                          style: TypographyTokens.bodySmall(
                            context.afriSemanticColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (recoveryRequested &&
                    state.status != GameOperationsLoadStatus.loading) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriInlineValidation(
                    tone: AfriInlineValidationTone.error,
                    message: l10n.gameTvRecoveryUnavailable,
                  ),
                ],
                if (state.status == GameOperationsLoadStatus.loading &&
                    state.inventory != null) ...[
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriInlineValidation(
                    key: const ValueKey<String>('pair-tv-syncing-warning'),
                    message: l10n.gameTvInventoryRefreshing,
                  ),
                ],
                const SizedBox(height: SpacingTokens.spacing5),
                AfriInputField(
                  key: const ValueKey<String>('pair-tv-challenge'),
                  controller: _challengeController,
                  label: l10n.gameTvChallenge,
                  hint: l10n.gameTvChallengeHint,
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    UpperCaseTextFormatter(),
                  ],
                  onChanged: _handleFormChanged,
                ),
                if (!recoveryRequested) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriInputField(
                    key: const ValueKey<String>('pair-tv-name'),
                    controller: _nameController,
                    label: l10n.gameTvName,
                    hint: l10n.gameTvNameHint,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    onChanged: _handleFormChanged,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  if (selectedScope != null)
                    AfriDropdownField<String>(
                      key: const ValueKey<String>('pair-tv-scope'),
                      initialValue: selectedScope.key,
                      label: l10n.gameTvAuthorizedScope,
                      items: options
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
                    )
                  else if (state.status != GameOperationsLoadStatus.loading)
                    AfriInlineValidation(
                      tone: AfriInlineValidationTone.error,
                      message: l10n.gameNoAuthorizedTvScopes,
                    ),
                ],
                if (_validationMessage != null) ...[
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriInlineValidation(
                    tone: AfriInlineValidationTone.error,
                    message: _validationMessage!,
                  ),
                ],
                if (state.failure != null) ...[
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriInlineValidation(
                    tone: AfriInlineValidationTone.error,
                    message: gameOperationsFailureDescription(
                      l10n,
                      state.failure!,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    key: const ValueKey<String>(
                      'pair-tv-refresh-after-failure',
                    ),
                    label: l10n.gameRefresh,
                    icon: AfriIcons.refresh,
                    variant: AfriButtonVariant.outline,
                    onTap: controller.load,
                  ),
                ],
                const SizedBox(height: SpacingTokens.spacing6),
                AfriButton(
                  key: const ValueKey<String>('pair-tv-submit'),
                  label: recoveryRequested
                      ? l10n.gameRecoverTvAction
                      : l10n.gamePairTvAction,
                  icon: AfriIcons.check,
                  isLoading: state.mutating,
                  enabled:
                      state.canStartPairingOperation &&
                      _formIsValid(
                        recoveryRequested: recoveryRequested,
                        selectedScope: selectedScope,
                        recoveryDisplay: recoveryDisplay,
                      ),
                  onTap: () => _pair(options, recoveryDisplay),
                ),
              ],
            ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
