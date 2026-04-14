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
  bool _isSaving = false;

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
    if (profile == null) return;

    setState(() => _isSaving = true);

    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(
          profile.copyWith(fullName: _nicknameController.text.trim()),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _showMessage(error);
      return;
    }

    _showMessage('Profile updated.');
    context.go('/settings');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        appBar: AppBar(
          title: Text('Profile', style: TypographyTokens.headlineSmall()),
          leading: IconButton(
            onPressed: () => closeSettingsChild(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: Column(
            children: [
              GlassCard(
                animate: false,
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.person_rounded, size: 28),
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
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Public alias',
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
              _SettingsInput(
                label: 'Nickname',
                hint: 'Optional supporter nickname',
                controller: _nicknameController,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Language', style: TypographyTokens.labelSmall()),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(languageLabel, style: TypographyTokens.bodyLarge()),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              ClaymorphicButton(
                label: _isSaving ? 'Saving...' : 'Save changes',
                preserveCase: true,
                width: double.infinity,
                onPressed: _isSaving ? null : _saveProfile,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDeleteAccountConfirmDialog(
                    context,
                  );
                  if (!context.mounted) return;
                  if (!confirmed) return;
                  final error = await ref
                      .read(authStateProvider.notifier)
                      .deleteAccount();
                  if (!context.mounted) return;
                  if (error != null) {
                    _showMessage(error);
                    return;
                  }
                  context.go('/onboarding');
                },
                child: Text(
                  'Delete account',
                  style: TypographyTokens.labelLarge().copyWith(
                    color: ColorTokens.error,
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

class _SettingsInput extends StatelessWidget {
  const _SettingsInput({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
