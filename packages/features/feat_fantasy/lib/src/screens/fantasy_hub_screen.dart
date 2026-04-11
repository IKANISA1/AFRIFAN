import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

class FantasyHubScreen extends ConsumerWidget {
  const FantasyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureEnabled = ref.watch(fantasyFeatureEnabledProvider);
    final competitions = ref.watch(fantasyCompetitionsProvider);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing2,
                  ),
                  child: _FantasyHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: featureEnabled.when(
                    data: (enabled) {
                      if (!enabled) {
                        return const _FantasyStateCard(
                          title: 'Fantasy is not live for this club yet.',
                          body:
                              'Enable the fantasy flags and publish a competition for this club to surface it here.',
                        );
                      }
                      return competitions.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return const _FantasyStateCard(
                              title: 'No competitions are available yet.',
                              body:
                                  'Published fantasy competitions will appear here once they are enabled for supporters.',
                            );
                          }

                          final featured = items.firstWhere(
                            (item) => item.isFeatured,
                            orElse: () => items.first,
                          );

                          return Column(
                            children: [
                              _FeaturedCompetitionCard(competition: featured),
                              const SizedBox(height: SpacingTokens.spacing5),
                              ...items.map(
                                (competition) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: SpacingTokens.spacing4,
                                  ),
                                  child: _CompetitionListCard(
                                    competition: competition,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: SpacingTokens.spacing6,
                          ),
                          child: AfriSkeletonList(itemCount: 3),
                        ),
                        error: (_, __) => const _FantasyStateCard(
                          title: 'Fantasy could not load.',
                          body:
                              'The competition hub is temporarily unavailable. Pull to refresh or try again shortly.',
                        ),
                      );
                    },
                    loading: () => const _FantasyStateCard(
                      title: 'Loading fantasy surfaces…',
                      body:
                          'Checking competition availability and rollout status.',
                    ),
                    error: (_, __) => const _FantasyStateCard(
                      title: 'Fantasy configuration failed to load.',
                      body:
                          'The app could not resolve rollout flags for fantasy right now.',
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: SpacingTokens.spacing20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FantasyHeader extends StatelessWidget {
  const _FantasyHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FANTASY FOOTBALL',
                style: TypographyTokens.titleSmall().copyWith(letterSpacing: 2),
              ),
              Text(
                'Competition Hub',
                style: TypographyTokens.displaySmall(ColorTokens.clubAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedCompetitionCard extends StatelessWidget {
  const _FeaturedCompetitionCard({required this.competition});

  final FantasyCompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: [
              _Pill(label: competition.statusLabel),
              _Pill(label: competition.modeLabel),
              if (competition.provider != null)
                _Pill(label: competition.provider!.toUpperCase()),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            competition.heroTitle.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ColorTokens.onSurface,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(competition.heroBody, style: TypographyTokens.bodyMedium()),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              Expanded(
                child: Text(
                  competition.season,
                  style: TypographyTokens.labelLarge().copyWith(
                    color: ColorTokens.clubAccent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/fantasy/${competition.slug}'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(competition.ctaLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompetitionListCard extends StatelessWidget {
  const _CompetitionListCard({required this.competition});

  final FantasyCompetitionSummary competition;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  competition.name.toUpperCase(),
                  style: TypographyTokens.titleLarge().copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Text(
                  '${competition.season}  •  ${competition.modeLabel}',
                  style: TypographyTokens.labelMedium().copyWith(
                    color: ColorTokens.clubAccent,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  competition.description,
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          IconButton.filledTonal(
            onPressed: () => context.push('/fantasy/${competition.slug}'),
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'Open competition',
          ),
        ],
      ),
    );
  }
}

class _FantasyStateCard extends StatelessWidget {
  const _FantasyStateCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TypographyTokens.titleLarge().copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(body, style: TypographyTokens.bodyMedium()),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surface.withValues(alpha: 0.65),
        borderRadius: ShapeTokens.chipRadius,
        border: BorderTokens.ghost(opacity: 0.12),
      ),
      child: Text(
        label,
        style: TypographyTokens.labelSmall().copyWith(
          color: ColorTokens.clubAccent,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
