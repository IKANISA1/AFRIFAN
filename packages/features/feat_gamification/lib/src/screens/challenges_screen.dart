import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

const _tutorialSeenKey = 'fanzone_tutorial_seen';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  List<_ChallengeData> _daily = const <_ChallengeData>[];
  List<_ChallengeData> _weekly = const <_ChallengeData>[];
  List<_ChallengeData> _seasonal = const <_ChallengeData>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadChallenges());
    _maybeShowTutorial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// M-1: Show first-time FET/prediction tutorial if the user has never seen it.
  void _maybeShowTutorial() {
    final seen = HiveCacheService.getJson<bool>(_tutorialSeenKey);
    if (seen == true) return;

    // Wait a beat for the screen to build before showing the tutorial.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showFetTutorial();
    });
  }

  void _showFetTutorial() {
    unawaited(
      showAfriBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _FetTutorialSheet(),
      ).then((_) => HiveCacheService.putJson(_tutorialSeenKey, true)),
    );
  }

  Future<void> _loadChallenges() async {
    try {
      final context = await ref
          .read(fetRepositoryProvider)
          .loadExperienceContext();
      final daily = <_ChallengeData>[];
      final weekly = <_ChallengeData>[];
      final seasonal = <_ChallengeData>[];

      for (final item in context.catalog) {
        final challenge = _ChallengeData(
          title: item.itemName,
          reward: '+${item.fetValue} pts',
          progress: context.earnedCodes.contains(item.code) ? 1 : 0,
          progressLabel: context.earnedCodes.contains(item.code)
              ? 'Completed'
              : item.triggerCondition,
        );
        switch (item.challengeBucket) {
          case FetChallengeBucket.daily:
            daily.add(challenge);
            break;
          case FetChallengeBucket.weekly:
            weekly.add(challenge);
            break;
          case FetChallengeBucket.seasonal:
            seasonal.add(challenge);
            break;
        }
      }

      if (!mounted) return;
      setState(() {
        _daily = daily;
        _weekly = weekly;
        _seasonal = seasonal;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'ChallengesScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Challenges are temporarily unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'CHALLENGES',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
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
            Tab(text: 'DAILY'),
            Tab(text: 'WEEKLY'),
            Tab(text: 'SEASONAL'),
          ],
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Challenges unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadChallenges,
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_daily),
                _buildList(_weekly),
                _buildList(_seasonal),
              ],
            ),
    );
  }

  Widget _buildList(List<_ChallengeData> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: GlassCard(
            animate: false,
            child: Text(
              'Challenges appear once your supporter profile is active.',
              style: TypographyTokens.bodyMedium(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: items
          .map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _ChallengeCard(data: item),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ChallengeData {
  const _ChallengeData({
    required this.title,
    required this.reward,
    required this.progress,
    required this.progressLabel,
  });

  final String title;
  final String reward;
  final double progress;
  final String progressLabel;
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.data});

  final _ChallengeData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title.toUpperCase(),
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(data.reward, style: TypographyTokens.bodyLarge()),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriLinearProgressIndicator(
            value: data.progress,
            color: ColorTokens.clubAccent,
            backgroundColor: ColorTokens.surfaceContainerHighest,
            minHeight: SpacingTokens.spacing2,
            borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(data.progressLabel, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}

// ── M-1: First-Time FET Tutorial Sheet ─────────────────────────────────

class _FetTutorialSheet extends StatefulWidget {
  const _FetTutorialSheet();

  @override
  State<_FetTutorialSheet> createState() => _FetTutorialSheetState();
}

class _FetTutorialSheetState extends State<_FetTutorialSheet> {
  int _currentStep = 0;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      icon: AfriIcons.fetToken,
      title: 'WHAT IS FET?',
      body:
          'FET (Fan Engagement Tokens) are your supporter currency. '
          'Earn them by engaging with your club — attending matches, '
          'completing challenges, making predictions, and supporting the community.',
    ),
    _TutorialStep(
      icon: AfriIcons.versus,
      title: 'HOW PREDICTIONS WORK',
      body:
          'Browse upcoming fixtures, choose pick types like Match Result, '
          'Goals, and Scorers, then lock in picks before kickoff. '
          'Correct picks earn points based on difficulty.',
    ),
    _TutorialStep(
      icon: AfriIcons.wallet,
      title: 'EARN, LEVEL UP & REDEEM',
      body:
          'Your points balance grows as you engage. Climb the leaderboard, '
          'unlock membership tiers, and redeem rewards '
          'from the club store. Every action counts.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (index) {
              return AnimatedContainer(
                duration: AfriMotion.standard,
                width: index == _currentStep
                    ? SpacingTokens.spacing6
                    : SpacingTokens.spacing2,
                height: SpacingTokens.spacing2,
                margin: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: index == _currentStep
                      ? ColorTokens.clubAccent
                      : ColorTokens.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
                ),
              );
            }),
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // Icon
          Icon(
            step.icon,
            size: SpacingTokens.spacing12,
            color: ColorTokens.clubAccent,
          ),
          const SizedBox(height: SpacingTokens.spacing4),

          // Title
          Text(
            step.title,
            style: TypographyTokens.headlineSmall().copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing3),

          // Body
          Text(
            step.body,
            style: TypographyTokens.bodyMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // Actions
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: AfriButton(
                    label: 'BACK',
                    variant: AfriButtonVariant.secondary,
                    onTap: () => setState(() => _currentStep--),
                  ),
                ),
              if (_currentStep > 0)
                const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: AfriButton(
                  label: isLast ? 'GET STARTED' : 'NEXT',
                  onTap: () {
                    if (isLast) {
                      context.pop();
                    } else {
                      setState(() => _currentStep++);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
