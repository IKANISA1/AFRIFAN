import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/settings_navigation_scope.dart';
import '../widgets/settings_overlays.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  late final FocusNode _nicknameFocusNode;
  bool _isBusy = false;
  String? _nicknameError;

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
    final profile = ref.read(currentUserProvider);
    if (profile == null || _isBusy) return;

    setState(() {
      _isBusy = true;
      _nicknameError = null;
    });

    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(
          profile.copyWith(fullName: _nicknameController.text.trim()),
        );

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _nicknameError = error;
    });

    if (error != null) {
      if (error.contains('changed on another device')) {
        final refreshError = await ref
            .read(authStateProvider.notifier)
            .refreshProfile();
        if (!mounted) return;
        final refreshed = ref.read(currentUserProvider);
        if (refreshError == null && refreshed != null) {
          _nicknameController.text = refreshed.displayName ?? '';
          setState(() => _nicknameError = null);
          unawaited(
            FirebaseAnalyticsService.logErrorRecovery(
              surface: 'profile_settings',
              outcome: 'conflict_refresh',
            ),
          );
          _showMessage(
            'Profile changed elsewhere. The latest nickname is loaded; review it before saving again.',
          );
          return;
        }
      }
      _nicknameFocusNode.requestFocus();
      _showMessage(error);
      return;
    }

    _showMessage('Profile updated.');
    context.go('/settings');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AfriToast.info(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProvider);
    if (profile == null) {
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
          child: AfriErrorView(
            key: const ValueKey('profile-unavailable'),
            message:
                'Your profile is unavailable. Sign in again to recover your account.',
            actionLabel: 'Sign in again',
            onRetry: () => context.go(
              '/auth/phone?from=${Uri.encodeComponent('/settings/edit-profile')}',
            ),
          ),
        ),
      );
    }
    final alias = AliasGenerator.format(
      profile.publicUserId ?? AliasGenerator.generate(),
    );
    final languageLabel = _languageLabel(profile.languageCode);

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
              label: 'Nickname',
              hint: 'Optional supporter nickname',
              controller: _nicknameController,
              focusNode: _nicknameFocusNode,
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
              label: _isBusy ? 'Saving…' : 'Save changes',
              onTap: _saveProfile,
              isLoading: _isBusy,
              enabled: !_isBusy,
            ),
            const SizedBox(height: SpacingTokens.spacing8),
            GlassCard(
              animate: false,
              child: AfriPressFeedback(
                onTap: _isBusy
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
                          _showMessage(error);
                          return;
                        }
                        context.go('/onboarding');
                      },
                enabled: !_isBusy,
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
