import 'dart:async';

import 'package:core_auth/core_auth.dart';
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

    _showMessage('Profile updated.');
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
        'Profile service is temporarily unavailable.',
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
    if (asyncContent.isLoading) {
      return _buildProfileShell(
        context,
        child: AfriStateView.loading(
          key: const ValueKey<String>('profile-state-loading'),
          title: 'Loading profile',
          message: 'Checking your saved profile.',
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
        title: 'Profile access limited',
        message: 'Your profile could not be verified. Sign in again.',
        actionLabel: 'Sign in again',
        onAction: () => context.go(
          '/auth/phone?from=${Uri.encodeComponent('/settings/edit-profile')}',
        ),
      ),
      ProfileRouteContentFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('profile-state-conflict'),
        title: 'Profile changed',
        message: 'Refresh to load the current profile before editing.',
        actionLabel: 'Refresh',
        onAction: () =>
            unawaited(ref.read(profileRouteContentProvider.notifier).refresh()),
      ),
      ProfileRouteContentFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('profile-state-security-timeout'),
        title: 'Profile security check timed out',
        message: 'Check your connection and refresh.',
        actionLabel: 'Refresh',
        onAction: () =>
            unawaited(ref.read(profileRouteContentProvider.notifier).refresh()),
      ),
      ProfileRouteContentFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('profile-state-error'),
        title: 'Could not load profile',
        message: 'Your profile is still safe. Try again.',
        actionLabel: 'Try again',
        onAction: () =>
            unawaited(ref.read(profileRouteContentProvider.notifier).refresh()),
      ),
    };
    return _buildProfileShell(context, child: state);
  }

  Widget _buildProfileShell(BuildContext context, {required Widget child}) {
    return SettingsBackGuard(
      child: AfriScreenScaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text('Profile', style: TypographyTokens.headlineSmall()),
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
    if (_isBusy) {
      return const AfriStateBanner(
        key: ValueKey<String>('profile-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Saving profile',
        subtitle: 'Your nickname stays visible while the save is confirmed.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (asyncContent.isRefreshing) {
      return const AfriStateBanner(
        key: ValueKey<String>('profile-state-refreshing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing profile',
        subtitle: 'Your saved profile stays visible.',
        tone: AfriStateBannerTone.info,
        trailing: AfriLoadingIndicator(size: SizeTokens.iconMd),
      );
    }
    if (_operationFailure != null) {
      return switch (_operationFailure!.kind) {
        ProfileRouteContentFailureKind.permissionDenied =>
          const AfriStateBanner(
            key: ValueKey<String>('profile-state-save-permission-denied'),
            icon: AfriIcons.lock,
            title: 'Profile editing unavailable',
            subtitle: 'Your saved profile stays visible.',
            tone: AfriStateBannerTone.warning,
          ),
        ProfileRouteContentFailureKind.conflict => AfriStateBanner(
          key: const ValueKey<String>('profile-state-save-conflict'),
          icon: AfriIcons.refresh,
          title: 'Profile changed elsewhere',
          subtitle: 'Latest nickname loaded. Review before saving.',
          onTap: _recoverProfile,
          tone: AfriStateBannerTone.warning,
        ),
        ProfileRouteContentFailureKind.securityTimeout => AfriStateBanner(
          key: const ValueKey<String>('profile-state-save-security-timeout'),
          icon: AfriIcons.lock,
          title: 'Profile save not confirmed',
          subtitle: 'Refresh your profile before trying again.',
          onTap: _recoverProfile,
          tone: AfriStateBannerTone.warning,
        ),
        ProfileRouteContentFailureKind.unknown => const AfriStateBanner(
          key: ValueKey<String>('profile-state-save-error'),
          icon: AfriIcons.statusError,
          title: 'Profile could not be saved',
          subtitle: 'Your nickname draft is still here.',
          tone: AfriStateBannerTone.danger,
        ),
      };
    }
    if (content.status == ProfileRouteContentStatus.localFallback) {
      return AfriStateBanner(
        key: const ValueKey<String>('profile-state-offline'),
        icon: AfriIcons.offline,
        title: 'Offline profile',
        subtitle: content.message,
        tone: AfriStateBannerTone.warning,
      );
    }
    if (!content.editingEnabled) {
      return AfriStateBanner(
        key: const ValueKey<String>('profile-state-disabled'),
        icon: AfriIcons.profile,
        title: 'Profile editing unavailable',
        subtitle: content.message,
        tone: AfriStateBannerTone.neutral,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          title: 'Profile unavailable',
          message:
              'Your profile is unavailable. Sign in again to recover your account.',
          actionLabel: 'Sign in again',
          onAction: () => context.go(
            '/auth/phone?from=${Uri.encodeComponent('/settings/edit-profile')}',
          ),
        ),
      );
    }
    final alias = AliasGenerator.format(
      profile.publicUserId ?? AliasGenerator.generate(),
    );
    final languageLabel = _languageLabel(profile.languageCode);
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
          title: Text('Profile', style: TypographyTokens.headlineSmall()),
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
                    initials: 'Supporter',
                    size: SizeTokens.avatarLg,
                  ),
                  const SizedBox(width: SpacingTokens.spacing4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#$alias',
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
              label: 'Nickname',
              hint: 'Optional supporter nickname',
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
              label: _isBusy ? 'Saving…' : 'Save changes',
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
                          _showMessage(
                            'Account could not be deleted. Try again.',
                          );
                          return;
                        }
                        context.go('/onboarding');
                      },
                enabled: canDelete,
                tooltip: 'Delete account',
                semanticsLabel: 'Delete account',
                semanticsHint: 'Permanently delete this supporter account',
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
                        'Delete account',
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

String _languageLabel(String? languageCode) {
  return switch ((languageCode ?? 'en').trim().toLowerCase()) {
    'fr' => 'Français',
    'rw' => 'English (Kinyarwanda soon)',
    _ => 'English',
  };
}

// _SettingsInput removed — replaced by AfriInputField from core_theme.
