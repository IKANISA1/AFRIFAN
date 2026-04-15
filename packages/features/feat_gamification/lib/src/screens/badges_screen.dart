import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../prediction_providers.dart';
import '../widgets/gamification_overlays.dart';

class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key});

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  List<PredictionBadge> _badges = const <PredictionBadge>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final badges = await ref
          .read(predictionRepositoryProvider)
          .loadUserBadges();

      if (!mounted) return;
      setState(() {
        _badges = badges;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _badges = const <PredictionBadge>[];
        _isLoading = false;
        _error = 'Badges are temporarily unavailable.';
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
          'YOUR BADGES',
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
                  title: 'Badges unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadBadges,
                ),
              ),
            )
          : _badges.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriEmptyView(
                  title: 'No badges unlocked yet',
                  message:
                      'Prediction milestone badges appear here once you hit the first win thresholds.',
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: GridView.builder(
                itemCount: _badges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: SpacingTokens.spacing3,
                  mainAxisSpacing: SpacingTokens.spacing3,
                ),
                itemBuilder: (context, index) {
                  final badge = _badges[index];
                  return GestureDetector(
                    onTap: () => showBadgeEarnedModal(
                      context,
                      badgeName: badge.badgeName,
                      description: badge.badgeDescription,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColorTokens.clubAccent.withValues(alpha: 0.18),
                        border: BorderTokens.all(color: ColorTokens.clubAccent),
                      ),
                      child: Icon(
                        _iconForBadge(badge.badgeSlug),
                        color: ColorTokens.clubAccent,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

IconData _iconForBadge(String badgeSlug) {
  final normalized = badgeSlug.toLowerCase();
  return switch (normalized) {
    final value when value.contains('legend') =>
      Icons.workspace_premium_rounded,
    final value when value.contains('gold') => Icons.emoji_events_rounded,
    final value when value.contains('silver') => Icons.bolt_rounded,
    final value when value.contains('bronze') =>
      Icons.local_fire_department_rounded,
    final value when value.contains('streak') =>
      Icons.local_fire_department_rounded,
    _ => Icons.star_rounded,
  };
}
