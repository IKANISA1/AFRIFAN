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
  late final TextEditingController _momoController;
  late final TextEditingController _nicknameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProvider);
    _momoController = TextEditingController(text: _initialMomoValue(profile));
    _nicknameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _momoController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final profile = ref.read(currentUserProvider);
    if (profile == null) return;

    final rawMomo = _momoController.text.trim();
    if (rawMomo.isEmpty) {
      _showMessage('Mobile money number is required.');
      return;
    }

    final country = _resolveCountry(profile);
    late final String normalizedMomo;
    try {
      normalizedMomo = country.buildE164Phone(rawMomo);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }

    setState(() => _isSaving = true);

    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(
          profile.copyWith(
            phone: normalizedMomo,
            momoNumber: normalizedMomo,
            momoProvider: country.providerId,
            country: country.isoCode,
            fullName: _nicknameController.text.trim(),
          ),
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

  AfriCountry _resolveCountry(UserProfile profile) {
    return AfriCountryCatalog.resolve(
      country: profile.country,
      phone: profile.momoNumber ?? profile.phone,
    );
  }

  String _initialMomoValue(UserProfile? profile) {
    final rawValue = profile?.momoNumber ?? profile?.phone;
    if (profile == null || rawValue == null || rawValue.trim().isEmpty) {
      return '';
    }

    try {
      return _resolveCountry(profile).normalizeNationalPhone(rawValue);
    } catch (_) {
      return rawValue;
    }
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
          title: Text(
            'EDIT PROFILE',
            style: TypographyTokens.monolithFont(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
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
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14),
                      ),
                      child: const Icon(Icons.person_rounded, size: 38),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Photo upload coming soon.'),
                          ),
                        );
                      },
                      child: const Text('+ PHOTO'),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$alias',
                        style: TypographyTokens.numericAlias(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PUBLIC IDENTITY',
                      style: TypographyTokens.labelSmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      'Your alias is fixed across club surfaces.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              _SettingsInput(
                label: 'NICKNAME',
                hint: 'Optional supporter nickname',
                controller: _nicknameController,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              _SettingsInput(
                label: 'LINKED MOMO NUMBER',
                hint: '+250 7XX XXX XXX',
                controller: _momoController,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LANGUAGE', style: TypographyTokens.labelSmall()),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(languageLabel, style: TypographyTokens.bodyLarge()),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      'Change in Language & Region settings.',
                      style: TypographyTokens.bodySmall(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              ClaymorphicButton(
                label: _isSaving ? 'SAVING...' : 'SAVE CHANGES',
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
                  'DELETE ACCOUNT',
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
    'rw' => 'Kinyarwanda',
    'fr' => 'Français',
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
