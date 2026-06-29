import 'package:core_auth/core_auth.dart';
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
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final profile = ref.read(currentUserProvider);
    if (profile == null || _isBusy) return;

    setState(() => _isBusy = true);

    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(
          profile.copyWith(fullName: _nicknameController.text.trim()),
        );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error != null) {
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
    final alias = AliasGenerator.format(
      profile?.publicUserId ?? AliasGenerator.generate(),
    );
    final languageLabel = _languageLabel(profile?.languageCode);

    return SettingsBackGuard(
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AfriAppBar(
          title: Text('Profile', style: TypographyTokens.headlineSmall()),
          leading: AfriIconButton(
            icon: AfriIcons.back,
            onTap: () => closeSettingsChild(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: Column(
            children: [
              GlassCard(
                animate: false,
                child: Row(
                  children: [
                    Container(
                      width: SizeTokens.avatarLg,
                      height: SizeTokens.avatarLg,
                      decoration: BoxDecoration(
                        color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusMd,
                        ),
                      ),
                      child: const Icon(
                        AfriIcons.profile,
                        size: SizeTokens.iconLg,
                      ),
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
                maxLength: 50,
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
                          final confirmed =
                              await showDeleteAccountConfirmDialog(context);
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
                      const Icon(
                        AfriIcons.delete,
                        color: ColorTokens.error,
                        size: SizeTokens.iconMd,
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Text(
                        'Delete account',
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
