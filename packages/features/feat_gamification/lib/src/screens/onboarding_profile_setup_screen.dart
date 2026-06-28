import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Onboarding profile setup screen — step-based flow.
///
/// Mirrors the fanafrika `Onboarding.tsx` Step 4 (PROFILE SETUP) —
/// username + favorite team selection. This is a standalone screen
/// shown after WhatsApp verification.
///
/// Saves `display_name` and `favorite_team_slug` to the `profiles` table on
/// completion.
class OnboardingProfileSetupScreen extends ConsumerStatefulWidget {
  const OnboardingProfileSetupScreen({super.key, this.onComplete});

  /// Called when the user completes setup.
  final VoidCallback? onComplete;

  @override
  ConsumerState<OnboardingProfileSetupScreen> createState() =>
      _OnboardingProfileSetupScreenState();
}

class _OnboardingProfileSetupScreenState
    extends ConsumerState<OnboardingProfileSetupScreen> {
  final _usernameController = TextEditingController();
  bool _isSaving = false;
  List<_TeamOption> _teams = const <_TeamOption>[_TeamOption.other()];
  _TeamOption _selectedTeam = const _TeamOption.other();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProvider);
    _usernameController.text = profile?.displayName ?? '';
    unawaited(_loadTeams());
  }

  Future<void> _loadTeams() async {
    final preferredTeamSlug = ref.read(currentUserProvider)?.favoriteTeamSlug;
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('football_team_catalog')
          .select('slug,name')
          .eq('is_active', true)
          .order('name')
          .limit(100);

      if (!mounted) return;
      final teamOptions = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(_TeamOption.fromJson)
          .where((option) => option.label.isNotEmpty)
          .toList();
      teamOptions.add(const _TeamOption.other());
      final selected = teamOptions.firstWhere(
        (option) => option.slug == preferredTeamSlug,
        orElse: () => teamOptions.first,
      );

      setState(() {
        _teams = teamOptions;
        _selectedTeam = selected;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'OnboardingProfileSetupScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) return;
      const fallbackOptions = <_TeamOption>[
        _TeamOption(label: 'My Club'),
        _TeamOption.other(),
      ];
      setState(() {
        _teams = fallbackOptions;
        _selectedTeam = fallbackOptions.first;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username.')));
      return;
    }

    setState(() => _isSaving = true);

    final profile = ref.read(currentUserProvider);
    if (profile == null) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to save this.')),
        );
      }
      return;
    }

    final error = await ref
        .read(authStateProvider.notifier)
        .updateProfile(
          profile.copyWith(
            displayName: username,
            favoriteTeamSlug: _selectedTeam.slug,
          ),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error == null) {
      widget.onComplete?.call();
      if (context.mounted && context.canPop()) {
        context.pop();
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // ── Title ──
                Text(
                      'PROFILE SETUP',
                      style: TypographyTokens.displaySmall().copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.05, end: 0, duration: 400.ms),

                const SizedBox(height: SpacingTokens.spacing2),

                Text(
                  'Customize your FANZONE experience.',
                  style: TypographyTokens.bodyMedium(),
                ).animate(delay: 100.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: SpacingTokens.spacing8),

                // ── Username ──
                Text(
                  'USERNAME',
                  style: TypographyTokens.metricLabel(
                    ColorTokens.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                AfriInputField(
                      label: 'Username',
                      hint: 'e.g. SoccerKing99',
                      controller: _usernameController,
                    )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.04, end: 0, duration: 300.ms),

                const SizedBox(height: SpacingTokens.spacing6),

                // ── Favorite Team ──
                Text(
                  'FAVORITE TEAM',
                  style: TypographyTokens.metricLabel(
                    ColorTokens.onSurfaceVariant,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: BorderTokens.ghost(),
                      ),
                      child: DropdownButton<_TeamOption>(
                        value: _selectedTeam,
                        isExpanded: true,
                        items: _teams
                            .map(
                              (team) => DropdownMenuItem<_TeamOption>(
                                value: team,
                                child: Text(
                                  team.label,
                                  style: TypographyTokens.bodyMedium(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedTeam = value);
                          }
                        },
                        underline: const SizedBox.shrink(),
                        dropdownColor: ColorTokens.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        icon: Icon(
                          AfriIcons.chevronDown,
                          color: ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.04, end: 0, duration: 300.ms),

                const Spacer(flex: 2),

                // ── Complete button ──
                AfriButton(
                      label: _isSaving ? 'Saving…' : 'Complete setup',
                      icon: _isSaving ? null : AfriIcons.checkGroup,
                      onTap: _isSaving ? () {} : () => _handleComplete(),
                    )
                    .animate(delay: 400.ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.06, end: 0, duration: 300.ms),

                const SizedBox(height: SpacingTokens.spacing4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamOption {
  const _TeamOption({required this.label, this.slug});

  const _TeamOption.other() : label = 'Other', slug = null;

  factory _TeamOption.fromJson(Map<String, dynamic> json) {
    return _TeamOption(
      label: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
    );
  }

  final String label;
  final String? slug;

  @override
  bool operator ==(Object other) {
    return other is _TeamOption && other.label == label && other.slug == slug;
  }

  @override
  int get hashCode => Object.hash(label, slug);
}
