import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile_route_content_provider.dart';
import '../widgets/settings_navigation_scope.dart';
import '../widgets/settings_overlays.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    this.operationTimeout = const Duration(seconds: 12),
    super.key,
  });

  final Duration operationTimeout;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  late final FocusNode _nicknameFocusNode;
  bool _isBusy = false;
  bool _saveBlocked = false;
  String? _nicknameError;
  ProfileRouteContentFailure? _operationFailure;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    _nicknameFocusNode = FocusNode(debugLabel: 'Nickname');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final content = ref.read(profileRouteContentProvider).valueOrNull;
    final profile = content?.profile;
    if (profile == null ||
        _isBusy ||
        _saveBlocked ||
        !content!.editingEnabled ||
        content.status == ProfileRouteContentStatus.localFallback) {
      return;
    }

    setState(() {
      _isBusy = true;
      _nicknameError = null;
      _operationFailure = null;
    });

    ProfileRouteContentFailure? failure;
    try {
      final error = await ref
          .read(authStateProvider.notifier)
          .updateProfile(
            profile.copyWith(fullName: _nicknameController.text.trim()),
          )
          .timeout(widget.operationTimeout);
      if (error != null) {
        failure = ProfileRouteContentFailure.fromMessage(error);
      }
    } catch (error) {
      failure = ProfileRouteContentFailure.fromError(error);
    }

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (failure != null) {
      await _handleSaveFailure(failure);
      return;
    }

    _showMessage(context.afriL10n.editProfileUpdated);
    context.go('/settings');
  }

  Future<void> _handleSaveFailure(ProfileRouteContentFailure failure) async {
    if (failure.kind == ProfileRouteContentFailureKind.conflict) {
      try {
        final refreshError = await ref
            .read(authStateProvider.notifier)
            .refreshProfile()
            .timeout(widget.operationTimeout);
        if (!mounted) return;
        final refreshed = ref.read(currentUserProvider);
        if (refreshError == null && refreshed != null) {
          _nicknameController.text = refreshed.displayName ?? '';
          setState(() {
            _nicknameError = null;
            _operationFailure = failure;
          });
          ref.invalidate(profileRouteContentProvider);
          unawaited(
            FirebaseAnalyticsService.logErrorRecovery(
              surface: 'profile_settings',
              outcome: 'conflict_refresh',
            ),
          );
          return;
        }
      } catch (_) {
        failure = const ProfileRouteContentFailure(
          ProfileRouteContentFailureKind.securityTimeout,
        );
      }
    }

    final blocksFurtherSaves =
        failure.kind == ProfileRouteContentFailureKind.permissionDenied ||
        failure.kind == ProfileRouteContentFailureKind.securityTimeout;
    final fieldError = switch (failure.kind) {
      ProfileRouteContentFailureKind.unknown =>
        context.afriL10n.editProfileServiceUnavailable,
      _ => null,
    };
    setState(() {
      _operationFailure = failure;
      _nicknameError = fieldError;
      _saveBlocked = blocksFurtherSaves;
    });
    if (fieldError != null) {
      _nicknameFocusNode.requestFocus();
      _showMessage(fieldError);
    }
  }

  Future<void> _recoverProfile() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final error = await ref
          .read(authStateProvider.notifier)
          .refreshProfile()
          .timeout(widget.operationTimeout);
      if (!mounted) return;
      final refreshed = ref.read(currentUserProvider);
      if (error == null && refreshed != null) {
        _nicknameController.text = refreshed.displayName ?? '';
        setState(() {
          _isBusy = false;
          _saveBlocked = false;
          _nicknameError = null;
          _operationFailure = null;
        });
        ref.invalidate(profileRouteContentProvider);
        return;
      }
    } catch (_) {
      // The stable timeout state below intentionally hides raw diagnostics.
    }
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _saveBlocked = true;
      _operationFailure = const ProfileRouteContentFailure(
        ProfileRouteContentFailureKind.securityTimeout,
      );
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AfriToast.info(context, message);
  }

  Widget _buildUnavailableRoute(
    BuildContext context,
    AsyncValue<ProfileRouteContentSnapshot> asyncContent,
  ) {
    final l10n = context.afriL10n;
    if (asyncContent.isLoading) {
      return _buildProfileShell(
        context,
        child: AfriStateView.loading(
          key: const ValueKey<String>('profile-state-loading'),
          title: l10n.editProfileLoadingTitle,
          message: l10n.editProfileLoadingMessage,
        ),
      );
    }

    final failure = ProfileRouteContentFailure.fromError(
      asyncContent.error ??
          const ProfileRouteContentFailure(
            ProfileRouteContentFailureKind.unknown,
          ),
    );
    final state = switch (failure.kind) {
      ProfileRouteContentFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('profile-state-permission-denied'),
        title: l10n.editProfileAccessLimitedTitle,
        message: l10n.editProfileAccessLimitedMessage,
        actionLabel: l10n.editProfileSignInAgain,
        onAction: () => context.go(
          '/auth/phone?from=${Uri.encodeComponent('/settings/edit-profile')}',
        ),
      ),
      ProfileRouteContentFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('profile-state-conflict'),
        title: l10n.editProfileChangedTitle,
        message: l10n.editProfileChangedMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: () =>
            unawaited(ref.read(profileRouteContentProvider.notifier).refresh()),
      ),
      ProfileRouteContentFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('profile-state-security-timeout'),
        title: l10n.editProfileSecurityTimeoutTitle,
        message: l10n.editProfileSecurityTimeoutMessage,
        actionLabel: l10n.editProfileRefresh,
        onAction: () =>
            unawaited(ref.read(profileRouteContentProvider.notifier).refresh()),
      ),
      ProfileRouteContentFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('profile-state-error'),
        title: l10n.editProfileLoadFailedTitle,
        message: l10n.editProfileLoadFailedMessage,
        actionLabel: l10n.editProfileTryAgain,
        onAction: () =>
            unawaited(ref.read(profileRouteContentProvider.notifier).refresh()),
      ),
    };
    return _buildProfileShell(context, child: state);
  }

  Widget _buildProfileShell(BuildContext context, {required Widget child}) {
    final l10n = context.afriL10n;
    return SettingsBackGuard(
      child: AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text(
            l10n.editProfileTitle,
            style: TypographyTokens.headlineSmall(),
          ),
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => closeSettingsChild(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        scrollable: false,
        constrainContent: true,
        child: child,
      ),
    );
  }

  Widget? _buildRouteStateBanner(
    AsyncValue<ProfileRouteContentSnapshot> asyncContent,
    ProfileRouteContentSnapshot content,
  ) {
    final l10n = context.afriL10n;
    if (_isBusy) {
      return AfriStateBanner(
        key: const ValueKey<String>('profile-state-syncing'),
        icon: AfriIcons.refresh,
        title: l10n.editProfileSavingTitle,
        subtitle: l10n.editProfileSavingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (asyncContent.isRefreshing) {
      return AfriStateBanner(
        key: const ValueKey<String>('profile-state-refreshing'),
        icon: AfriIcons.refresh,
        title: l10n.editProfileRefreshingTitle,
        subtitle: l10n.editProfileRefreshingMessage,
        tone: AfriStateBannerTone.info,
        trailing: const AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_operationFailure != null) {
      return switch (_operationFailure!.kind) {
        ProfileRouteContentFailureKind.permissionDenied => AfriStateBanner(
          key: const ValueKey<String>('profile-state-save-permission-denied'),
          icon: AfriIcons.lock,
          title: l10n.editProfileEditingUnavailableTitle,
          subtitle: l10n.editProfileEditingUnavailableMessage,
          tone: AfriStateBannerTone.warning,
        ),
        ProfileRouteContentFailureKind.conflict => AfriStateBanner(
          key: const ValueKey<String>('profile-state-save-conflict'),
          icon: AfriIcons.refresh,
          title: l10n.editProfileChangedElsewhereTitle,
          subtitle: l10n.editProfileChangedElsewhereMessage,
          onTap: _recoverProfile,
          tone: AfriStateBannerTone.warning,
        ),
        ProfileRouteContentFailureKind.securityTimeout => AfriStateBanner(
          key: const ValueKey<String>('profile-state-save-security-timeout'),
          icon: AfriIcons.lock,
          title: l10n.editProfileSaveUnconfirmedTitle,
          subtitle: l10n.editProfileSaveUnconfirmedMessage,
          onTap: _recoverProfile,
          tone: AfriStateBannerTone.warning,
        ),
        ProfileRouteContentFailureKind.unknown => AfriStateBanner(
          key: const ValueKey<String>('profile-state-save-error'),
          icon: AfriIcons.statusError,
          title: l10n.editProfileSaveFailedTitle,
          subtitle: l10n.editProfileSaveFailedMessage,
          tone: AfriStateBannerTone.danger,
        ),
      };
    }
    if (content.status == ProfileRouteContentStatus.localFallback) {
      return AfriStateBanner(
        key: const ValueKey<String>('profile-state-offline'),
        icon: AfriIcons.offline,
        title: l10n.editProfileOfflineTitle,
        subtitle: l10n.editProfileOfflineMessage,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (!content.editingEnabled) {
      return AfriStateBanner(
        key: const ValueKey<String>('profile-state-disabled'),
        icon: AfriIcons.profile,
        title: l10n.editProfileEditingUnavailableTitle,
        subtitle: content.message ?? l10n.editProfileEditingUnavailableMessage,
        tone: AfriStateBannerTone.neutral,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final asyncContent = ref.watch(profileRouteContentProvider);
    final content = asyncContent.valueOrNull;
    final profile = content?.profile;
    if (content == null) {
      return _buildUnavailableRoute(context, asyncContent);
    }
    if (profile == null) {
      return _buildProfileShell(
        context,
        child: AfriEmptyView(
          key: const ValueKey('profile-unavailable'),
          title: l10n.editProfileUnavailableTitle,
          message: l10n.editProfileUnavailableMessage,
          actionLabel: l10n.editProfileSignInAgain,
          onAction: () => context.go(
            '/auth/phone?from=${Uri.encodeComponent('/settings/edit-profile')}',
          ),
        ),
      );
    }
    final alias = AliasGenerator.format(
      profile.publicUserId ?? AliasGenerator.generate(),
    );
    final languageLabel = _languageLabel(l10n, profile.languageCode);
    final isOffline = content.status == ProfileRouteContentStatus.localFallback;
    final editingAvailable =
        content.editingEnabled &&
        !isOffline &&
        !_saveBlocked &&
        _operationFailure?.kind !=
            ProfileRouteContentFailureKind.permissionDenied;
    final canEdit = editingAvailable && !_isBusy;
    final canDelete = !isOffline && !_isBusy;
    final routeBanner = _buildRouteStateBanner(asyncContent, content);

    return SettingsBackGuard(
      child: AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text(
            l10n.editProfileTitle,
            style: TypographyTokens.headlineSmall(),
          ),
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => closeSettingsChild(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        padding: const EdgeInsets.all(SpacingTokens.screenPadding),
        scrollable: true,
        constrainContent: true,
        child: Column(
          children: [
            if (routeBanner != null) ...[
              routeBanner,
              const SizedBox(height: SpacingTokens.spacing5),
            ],
            GlassCard(
              animate: false,
              child: Row(
                children: [
                  AfriAvatar(
                    semanticLabel: alias,
                    initials: l10n.settingsRoleSupporter,
                    size: SizeTokens.avatarLg,
                  ),
                  const SizedBox(width: SpacingTokens.spacing4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.editProfileAlias(alias),
                          style: TypographyTokens.headlineSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing1),
                        Text(
                          languageLabel,
                          style: TypographyTokens.bodySmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriInputField(
              key: const ValueKey<String>('profile-nickname-field'),
              label: l10n.editProfileNicknameLabel,
              hint: l10n.editProfileNicknameHint,
              controller: _nicknameController,
              focusNode: _nicknameFocusNode,
              enabled: canEdit,
              maxLength: 50,
              errorText: _nicknameError,
              autofillHints: const <String>[AutofillHints.nickname],
              onChanged: (_) {
                if (_nicknameError != null) {
                  setState(() => _nicknameError = null);
                }
              },
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            AfriButton(
              key: const ValueKey<String>('profile-save-action'),
              label: _isBusy
                  ? l10n.editProfileSaving
                  : l10n.editProfileSaveChanges,
              onTap: _saveProfile,
              isLoading: _isBusy,
              enabled: canEdit,
              labelMaxLines: 2,
            ),
            const SizedBox(height: SpacingTokens.spacing8),
            GlassCard(
              animate: false,
              child: AfriPressFeedback(
                key: const ValueKey<String>('profile-delete-action'),
                onTap: !canDelete
                    ? null
                    : () async {
                        final confirmed = await showDeleteAccountConfirmDialog(
                          context,
                        );
                        if (!context.mounted) return;
                        if (!confirmed) return;
                        setState(() => _isBusy = true);
                        final error = await ref
                            .read(authStateProvider.notifier)
                            .deleteAccount();
                        if (!context.mounted) return;
                        setState(() => _isBusy = false);
                        if (error != null) {
                          _showMessage(l10n.editProfileDeleteFailed);
                          return;
                        }
                        context.go('/onboarding');
                      },
                enabled: canDelete,
                tooltip: l10n.editProfileDeleteAccount,
                semanticsLabel: l10n.editProfileDeleteAccount,
                semanticsHint: l10n.editProfileDeleteHint,
                child: Row(
                  children: [
                    Icon(
                      AfriIcons.delete,
                      color: ColorTokens.error,
                      size: SizeTokens.iconMd,
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Text(
                        l10n.editProfileDeleteAccount,
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _languageLabel(AfriLocalizations l10n, String? languageCode) {
  return switch ((languageCode ?? 'en').trim().toLowerCase()) {
    'fr' => l10n.editProfileLanguageFrench,
    'rw' => l10n.editProfileLanguageKinyarwanda,
    _ => l10n.editProfileLanguageEnglish,
  };
}

// _SettingsInput removed — replaced by AfriInputField from core_theme.
