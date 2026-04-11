import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/settings_navigation_scope.dart';

class LanguageRegionScreen extends ConsumerStatefulWidget {
  const LanguageRegionScreen({super.key});

  @override
  ConsumerState<LanguageRegionScreen> createState() =>
      _LanguageRegionScreenState();
}

class _LanguageRegionScreenState extends ConsumerState<LanguageRegionScreen> {
  late String _languageCode;
  bool _isSaving = false;

  static const Map<String, String> _languageOptions = <String, String>{
    'en': 'English',
    'fr': 'Français',
  };

  @override
  void initState() {
    super.initState();
    final preferred = (ref.read(currentUserProvider)?.languageCode ?? 'en')
        .toLowerCase();
    _languageCode = _languageOptions.containsKey(preferred) ? preferred : 'en';
  }

  Future<void> _saveLanguage() async {
    final profile = ref.read(currentUserProvider);
    if (profile == null) return;

    setState(() => _isSaving = true);
    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(profile.copyWith(languageCode: _languageCode));

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Language preference updated.')),
    );

    if (error == null) {
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsBackGuard(
      child: Scaffold(
        backgroundColor: ColorTokens.background,
        appBar: AppBar(
          title: Text(
            'LANGUAGE & REGION',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENCY', style: TypographyTokens.labelSmall()),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      '${context.afriCurrencySymbol} (${context.afriCurrencyCode})',
                      style: TypographyTokens.bodyLarge(),
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
                    Text('APP LANGUAGE', style: TypographyTokens.labelSmall()),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      'English and French are currently supported in this build.',
                      style: TypographyTokens.bodyLarge(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      'Kinyarwanda support is in progress and is not yet selectable.',
                      style: TypographyTokens.bodySmall(
                        ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              ..._languageOptions.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.spacing3,
                  ),
                  child: GlassCard(
                    animate: false,
                    onTap: () => setState(() => _languageCode = entry.key),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TypographyTokens.bodyLarge(),
                          ),
                        ),
                        if (_languageCode == entry.key)
                          Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ClaymorphicButton(
                label: _isSaving ? 'SAVING...' : 'SAVE',
                width: double.infinity,
                onPressed: _isSaving ? null : _saveLanguage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
