import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fantasy_providers.dart';

class FantasyLaunchStrip extends ConsumerWidget {
  const FantasyLaunchStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredCompetitionAsync = ref.watch(
      fantasyFeaturedCompetitionProvider,
    );

    return featuredCompetitionAsync.when(
      data: (competition) {
        if (competition == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            SpacingTokens.spacing6,
            SpacingTokens.spacing6,
            0,
          ),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColorTokens.clubAccent.withValues(alpha: 0.16),
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: ColorTokens.clubAccent,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FANTASY FEATURE',
                            style: TypographyTokens.labelMedium().copyWith(
                              color: ColorTokens.clubAccent,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            competition.heroTitle,
                            style: TypographyTokens.titleLarge().copyWith(
                              fontWeight: FontWeight.w900,
                              color: ColorTokens.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  competition.heroBody,
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${competition.season}  •  ${competition.modeLabel}  •  ${competition.statusLabel}',
                        style: TypographyTokens.labelSmall().copyWith(
                          letterSpacing: 1.1,
                          color: ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '/fantasy/competition/${competition.slug}',
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(competition.ctaLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
