import 'dart:async';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  ConsumerState<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  FixtureSummary? _selectedFixture;
  int _homeScore = 2;
  int _awayScore = 1;
  int _stakeFet = 1000;
  bool _loading = true;
  List<FixtureSummary> _fixtures = [];

  @override
  void initState() {
    super.initState();
    _loadFixtures();
  }

  Future<void> _loadFixtures() async {
    try {
      final fixtures = await ref.read(predictionRepositoryProvider).loadFixtures();
      setState(() {
        _fixtures = fixtures.where((f) => f.isPredictable).toList();
        if (_fixtures.isNotEmpty) {
          _selectedFixture = _fixtures.first;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _submit() async {
    if (_selectedFixture == null) return;

    final success = await ref.read(challengeRepositoryProvider).createChallenge(
      matchId: _selectedFixture!.id,
      homeScore: _homeScore,
      awayScore: _awayScore,
      stakeFet: _stakeFet,
    );

    if (mounted) {
      if (success) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge created successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create challenge.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CREATE CHALLENGE',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AfriLoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(SpacingTokens.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fixture Selection ──
                  const _SectionHeader(title: '1. SELECT MATCH'),
                  const SizedBox(height: SpacingTokens.spacing3),
                  if (_fixtures.isEmpty)
                    const Text('No upcoming matches available.')
                  else
                    _FixtureDropdown(
                      fixtures: _fixtures,
                      selected: _selectedFixture,
                      onChanged: (f) => setState(() => _selectedFixture = f),
                    ),

                  const SizedBox(height: SpacingTokens.sectionGap),

                  // ── Score Picker ──
                  const _SectionHeader(title: '2. PREDICT EXACT SCORE'),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ScoreCounter(
                        label: _selectedFixture?.homeTeamShort ?? 'HOME',
                        value: _homeScore,
                        onChanged: (v) => setState(() => _homeScore = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          ':',
                          style: TypographyTokens.monolithFont(fontSize: 32),
                        ),
                      ),
                      _ScoreCounter(
                        label: _selectedFixture?.awayTeamShort ?? 'AWAY',
                        value: _awayScore,
                        onChanged: (v) => setState(() => _awayScore = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: SpacingTokens.sectionGap),

                  // ── Stake Selection ──
                  const _SectionHeader(title: '3. SET STAKE (FET)'),
                  const SizedBox(height: SpacingTokens.spacing3),
                  _StakeSlider(
                    value: _stakeFet,
                    onChanged: (v) => setState(() => _stakeFet = v),
                  ),

                  const SizedBox(height: SpacingTokens.sectionGap * 2),

                  AfriButton(
                    label: 'CREATE CHALLENGE',
                    icon: AfriIcons.checkGroup,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TypographyTokens.editorialFont(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ColorTokens.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _FixtureDropdown extends StatelessWidget {
  const _FixtureDropdown({
    required this.fixtures,
    required this.selected,
    required this.onChanged,
  });

  final List<FixtureSummary> fixtures;
  final FixtureSummary? selected;
  final ValueChanged<FixtureSummary?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FixtureSummary>(
          value: selected,
          isExpanded: true,
          dropdownColor: ColorTokens.surfaceContainerHigh,
          items: fixtures.map((f) {
            return DropdownMenuItem(
              value: f,
              child: Text(
                '${f.homeTeamShort} vs ${f.awayTeamShort} (${f.competitionName})',
                style: TypographyTokens.bodyMedium(),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ScoreCounter extends StatelessWidget {
  const _ScoreCounter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: TypographyTokens.labelSmall()),
        const SizedBox(height: 8),
        Row(
          children: [
            _IconButton(
              icon: Icons.remove,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
            ),
            const SizedBox(width: 16),
            Text(
              '$value',
              style: TypographyTokens.monolithFont(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            _IconButton(
              icon: Icons.add,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: ColorTokens.primaryTint(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: onTap == null ? Colors.white24 : Colors.white),
      ),
    );
  }
}

class _StakeSlider extends StatelessWidget {
  const _StakeSlider({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: value.toDouble(),
          min: 100,
          max: 10000,
          divisions: 99,
          activeColor: ColorTokens.clubAccent,
          inactiveColor: Colors.white10,
          onChanged: (v) => onChanged(v.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('100 FET', style: TypographyTokens.labelSmall()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ColorTokens.clubAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$value FET',
                style: TypographyTokens.monolithFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorTokens.clubAccent,
                ),
              ),
            ),
            Text('10k FET', style: TypographyTokens.labelSmall()),
          ],
        ),
      ],
    );
  }
}
