import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

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
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          reward: '+${item.fetValue} FET',
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
    } catch (_) {
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'CHALLENGES',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
        bottom: TabBar(
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
            style: TypographyTokens.monolithFont(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(data.reward, style: TypographyTokens.bodyLarge()),
          const SizedBox(height: SpacingTokens.spacing3),
          LinearProgressIndicator(
            value: data.progress,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: ColorTokens.surfaceContainerHighest,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(data.progressLabel, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}
