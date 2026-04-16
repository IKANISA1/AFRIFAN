import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_controller.dart';
import '../widgets/challenge_card.dart';

class ChallengeFeedScreen extends ConsumerWidget {
  const ChallengeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(challengeFeedProvider);

    return Scaffold(
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            // ── Top Bar ──
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: Text(
                'CHALLENGES',
                style: TypographyTokens.monolithFont(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () => ref.read(challengeFeedProvider.notifier).refresh(),
                  icon: const Icon(AfriIcons.refresh),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
              ],
            ),

            // ── Create CTA ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.screenPadding,
                  vertical: SpacingTokens.spacing4,
                ),
                child: AfriActionRow(
                  icon: AfriIcons.add,
                  label: 'CREATE A NEW CHALLENGE',
                  accentColor: ColorTokens.clubAccent,
                  onTap: () => context.push('/challenge/create'),
                ),
              ),
            ),

            // ── Feed Content ──
            feedAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: AfriLoadingIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                child: AfriStateView.error(
                  title: 'Load Failed',
                  message: 'Could not load challenges. Tap to retry.',
                  actionLabel: 'Retry',
                  onAction: () => ref.read(challengeFeedProvider.notifier).refresh(),
                ),
              ),
              data: (challenges) {
                if (challenges.isEmpty) {
                  return const SliverFillRemaining(
                    child: AfriEmptyView(
                      title: 'No Active Challenges',
                      message: 'Be the first to challenge the club!',
                      icon: AfriIcons.versus,
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    0,
                    SpacingTokens.screenPadding,
                    SpacingTokens.screenPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: SpacingTokens.spacing4),
                        child: ChallengeCard(challenge: challenges[index]),
                      ),
                      childCount: challenges.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
