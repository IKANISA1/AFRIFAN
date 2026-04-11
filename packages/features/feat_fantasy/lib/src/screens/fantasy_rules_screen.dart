import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

class FantasyRulesScreen extends ConsumerWidget {
  const FantasyRulesScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionAsync = ref.watch(fantasyCompetitionProvider(slug));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Fantasy rules'),
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: competitionAsync.when(
            data: (competition) {
              if (competition == null) {
                return const Center(child: Text('Competition not found.'));
              }

              final rules =
                  competition.mode == FantasyCompetitionMode.tournament
                  ? const [
                      'Build a tournament squad and react to stage deadlines.',
                      'Goals, assists, clean sheets, and bonus moments remain core scoring actions.',
                      'Round-advance bonuses can matter as much as single-match upside late in the bracket.',
                      'Transfer windows tighten as the tournament narrows.',
                    ]
                  : const [
                      'Build a season squad inside the competition budget.',
                      'Captaincy, vice-captain fallback, and bench structure matter every round.',
                      'Transfers create weekly tradeoffs between upside and point hits.',
                      'Ranks are shaped over time, not by one fixture alone.',
                    ];

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${competition.name} rules'.toUpperCase(),
                          style: TypographyTokens.titleLarge().copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        ...rules.map(
                          (rule) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SpacingTokens.spacing3,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    right: SpacingTokens.spacing3,
                                  ),
                                  child: Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: ColorTokens.clubAccent,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    rule,
                                    style: TypographyTokens.bodyMedium(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(itemCount: 2),
            ),
            error: (_, __) =>
                const Center(child: Text('Rules failed to load.')),
          ),
        ),
      ),
    );
  }
}
