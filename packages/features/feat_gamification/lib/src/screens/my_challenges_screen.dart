import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/challenge_controller.dart';
import '../models/challenge_models.dart';
import '../widgets/challenge_card.dart';

class MyChallengesScreen extends ConsumerStatefulWidget {
  const MyChallengesScreen({super.key});

  @override
  ConsumerState<MyChallengesScreen> createState() => _MyChallengesScreenState();
}

class _MyChallengesScreenState extends ConsumerState<MyChallengesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }

    unawaited(_loadForCurrentTab());
  }

  Future<void> _loadForCurrentTab() {
    final controller = ref.read(myChallengesProvider.notifier);
    return switch (_tabController.index) {
      0 => controller.loadOpen(),
      1 => controller.loadLocked(),
      2 => controller.loadSettled(),
      3 => controller.loadVoided(),
      _ => controller.loadOpen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myChallengesProvider);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'MY CHALLENGES',
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        bottom: AfriTabBar.line(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'Locked'),
            Tab(text: 'Settled'),
            Tab(text: 'Refunded'),
          ],
        ),
      ),
      body: AfriRefreshIndicator(
        onRefresh: _loadForCurrentTab,
        child: state.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            children: const [AfriSkeletonList()],
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            children: [
              AfriStateView.error(
                title: 'Could not load your challenges',
                message: error.toString(),
                actionLabel: 'Retry',
                onAction: () => unawaited(_loadForCurrentTab()),
              ),
            ],
          ),
          data: (items) => ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.all(SpacingTokens.screenPadding),
            children: items.isEmpty
                ? const [SizedBox.shrink()]
                : items
                      .map(
                        (challenge) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ChallengeCard(
                                challenge: challenge,
                                compact: true,
                              ),
                              if (challenge.myEntry != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: SpacingTokens.spacing2,
                                    left: SpacingTokens.spacing2,
                                  ),
                                  child: Text(
                                    _summaryFor(challenge),
                                    style: TypographyTokens.labelSmall(
                                      ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
          ),
        ),
      ),
    );
  }

  String _summaryFor(Challenge challenge) {
    final entry = challenge.myEntry;
    if (entry == null) {
      return '${challenge.totalPoolFet} FET pool';
    }

    return switch (entry.status) {
      ChallengeEntryStatus.winner => 'Won ${entry.payoutFet} FET',
      ChallengeEntryStatus.loser => 'Lost ${challenge.stakeFet} FET',
      ChallengeEntryStatus.refunded => 'Refunded ${entry.payoutFet} FET',
      ChallengeEntryStatus.cancelled => 'Cancelled',
      ChallengeEntryStatus.active =>
        'My pick ${entry.predictedHomeScore}-${entry.predictedAwayScore}',
    };
  }
}
