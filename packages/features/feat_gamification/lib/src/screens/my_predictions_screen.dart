import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class MyPredictionsScreen extends ConsumerStatefulWidget {
  const MyPredictionsScreen({super.key});

  @override
  ConsumerState<MyPredictionsScreen> createState() =>
      _MyPredictionsScreenState();
}

class _MyPredictionsScreenState extends ConsumerState<MyPredictionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<UserPrediction> _active = const <UserPrediction>[];
  List<UserPrediction> _history = const <UserPrediction>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(predictionRepositoryProvider);
      final results = await Future.wait<List<UserPrediction>>([
        repo.loadActivePredictions(),
        repo.loadPredictionHistory(),
      ]);

      if (!mounted) return;
      setState(() {
        _active = results[0];
        _history = results[1];
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MyPredictionsScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your activity right now.';
        _isLoading = false;
      });
    }
  }

  List<UserPrediction> get _settled => _history
      .where((prediction) => prediction.isSettled)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'MY ACTIVITY',
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
          tabs: [
            Tab(text: 'ACTIVE (${_active.length})'),
            Tab(text: 'SETTLED (${_settled.length})'),
            Tab(text: 'HISTORY (${_history.length})'),
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
                  title: 'Activity unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                MyPredictionsList(
                  items: _active,
                  onRefresh: _loadData,
                  onCancel: _cancelPrediction,
                  onOpenDetail: (prediction) =>
                      unawaited(context.push('/fanzone/my/${prediction.id}')),
                ),
                MyPredictionsList(
                  items: _settled,
                  onRefresh: _loadData,
                  onOpenDetail: (prediction) =>
                      unawaited(context.push('/fanzone/my/${prediction.id}')),
                ),
                MyPredictionsList(
                  items: _history,
                  onRefresh: _loadData,
                  onOpenDetail: (prediction) =>
                      unawaited(context.push('/fanzone/my/${prediction.id}')),
                ),
              ],
            ),
    );
  }

  Future<void> _cancelPrediction(UserPrediction prediction) async {
    unawaited(HapticFeedback.lightImpact());

    try {
      final result = await ref
          .read(predictionRepositoryProvider)
          .cancelPrediction(prediction.id);

      if (!mounted) return;
      if (!result.isError) {
        await _loadData();
        return;
      }

      AfriToast.error(context, result.message);
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'MyPredictionsScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) return;
      AfriToast.error(context, 'Could not cancel this pick.');
    }
  }
}

class MyPredictionsList extends StatelessWidget {
  const MyPredictionsList({
    super.key,
    required this.items,
    required this.onRefresh,
    this.onCancel,
    this.onOpenDetail,
  });

  final List<UserPrediction> items;
  final Future<void> Function() onRefresh;
  final Future<void> Function(UserPrediction prediction)? onCancel;
  final void Function(UserPrediction prediction)? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey<String>('my-predictions-empty'),
      );
    }

    return AfriRefreshIndicator(
      onRefresh: onRefresh,
      color: ColorTokens.clubAccent,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        itemBuilder: (context, index) {
          final prediction = items[index];
          return _PredictionCard(
            prediction: prediction,
            onTap: onOpenDetail == null
                ? null
                : () => onOpenDetail!(prediction),
            onCancel: onCancel == null ? null : () => onCancel!(prediction),
          );
        },
        separatorBuilder: (_, __) =>
            const SizedBox(height: SpacingTokens.spacing3),
        itemCount: items.length,
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction, this.onTap, this.onCancel});

  final UserPrediction prediction;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  Color _statusColor() {
    return switch (prediction.status) {
      PredictionStatus.won => ColorTokens.success,
      PredictionStatus.lost => ColorTokens.error,
      PredictionStatus.cancelled => ColorTokens.onSurfaceVariant,
      PredictionStatus.void_ => ColorTokens.onSurfaceVariant,
      _ => ColorTokens.warning,
    };
  }

  String _statusLabel() {
    return switch (prediction.status) {
      PredictionStatus.won => 'WON',
      PredictionStatus.lost => 'LOST',
      PredictionStatus.cancelled => 'CANCELLED',
      PredictionStatus.void_ => 'VOID',
      _ => 'PENDING',
    };
  }

  String _formatTime(DateTime? value) {
    if (value == null) return 'TBD';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${prediction.homeTeamShort.toUpperCase()} vs ${prediction.awayTeamShort.toUpperCase()}',
                style: TypographyTokens.titleMedium().copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing2,
                vertical: SpacingTokens.spacing1,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
              ),
              child: Text(
                _statusLabel(),
                style: TypographyTokens.labelSmall(color),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          prediction.marketName.toUpperCase(),
          style: TypographyTokens.labelMedium(ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          children: [
            _PredictionChip(label: prediction.selectedOutcome),
            _PredictionChip(
              label: prediction.isWon
                  ? '+${prediction.fetEarned} pts'
                  : '+${prediction.fetPotential} pts',
            ),
            if ((prediction.slipId ?? '').isNotEmpty)
              const _PredictionChip(label: 'Round'),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          '${prediction.competitionName} • ${_formatTime(prediction.placedAt)}',
          style: TypographyTokens.bodySmall(),
        ),
        if (onCancel != null) ...[
          const SizedBox(height: SpacingTokens.spacing3),
          Align(
            alignment: Alignment.centerLeft,
            child: AfriButton(
              label: 'Cancel',
              icon: AfriIcons.close,
              variant: AfriButtonVariant.secondary,
              onTap: onCancel!,
            ),
          ),
        ],
      ],
    );

    final card = GlassCard(animate: false, child: content);

    if (onTap == null) {
      return card;
    }

    return AfriPressFeedback(
      onTap: onTap!,
      semanticsLabel:
          '${prediction.homeTeam} versus ${prediction.awayTeam} activity',
      tooltip: 'Open activity detail',
      excludeChildSemantics: true,
      builder: (context, state) => AnimatedScale(
        scale: state.isPressed ? 0.99 : 1,
        duration: const Duration(milliseconds: 120),
        child: card,
      ),
    );
  }
}

class _PredictionChip extends StatelessWidget {
  const _PredictionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing2,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ShapeTokens.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
      ),
    );
  }
}
