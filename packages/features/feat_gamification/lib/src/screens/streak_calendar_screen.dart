import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/prediction_models.dart';
import '../prediction_providers.dart';

class StreakCalendarScreen extends ConsumerStatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  ConsumerState<StreakCalendarScreen> createState() =>
      _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends ConsumerState<StreakCalendarScreen> {
  List<int> _heat = const <int>[];
  int _currentStreak = 0;
  int _bestStreak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final repository = ref.read(predictionRepositoryProvider);
      final results = await Future.wait<Object?>([
        repository.loadUserStats(),
        repository.loadPredictionHistory(limit: 250),
      ]);
      final dashboard = results[0]! as PredictionDashboard;
      final history = results[1]! as List<UserPrediction>;
      final countsByDay = <String, int>{};
      for (final prediction in history.where((item) => item.isWon)) {
        final when =
            prediction.settledAt?.toLocal() ?? prediction.placedAt?.toLocal();
        if (when == null) continue;
        final key = DateTime(
          when.year,
          when.month,
          when.day,
        ).toIso8601String().split('T').first;
        countsByDay.update(key, (value) => value + 1, ifAbsent: () => 1);
      }

      final heat = <int>[];
      final today = DateTime.now();
      for (var offset = 34; offset >= 0; offset--) {
        final day = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: offset));
        final key = day.toIso8601String().split('T').first;
        heat.add(countsByDay[key] ?? 0);
      }

      var current = 0;
      for (var i = heat.length - 1; i >= 0; i--) {
        if (heat[i] > 0) {
          current++;
        } else {
          break;
        }
      }

      var best = 0;
      var running = 0;
      for (final value in heat) {
        if (value > 0) {
          running++;
          if (running > best) best = running;
        } else {
          running = 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _heat = heat;
        _currentStreak = dashboard.currentStreak > 0
            ? dashboard.currentStreak
            : current;
        _bestStreak = best;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _heat = List<int>.filled(35, 0);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextBonus = _currentStreak == 0
        ? 3
        : (((_currentStreak ~/ 7) + 1) * 7);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'YOUR STREAK',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: Column(
                children: [
                  Text(
                    '$_currentStreak DAYS',
                    style: TypographyTokens.monolithFont(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: ColorTokens.clubAccent,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    _currentStreak == 0
                        ? 'No activity streak has started yet.'
                        : 'Streak active.',
                    style: TypographyTokens.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _heat
                        .map((value) {
                          final normalized = value == 0
                              ? 0.08
                              : (value.clamp(1, 5) / 5);
                          return Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: ColorTokens.clubPrimary.withValues(
                                alpha: normalized,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  GlassCard(
                    animate: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StreakMetric(
                          label: 'CURRENT',
                          value: '$_currentStreak',
                        ),
                        _StreakMetric(label: 'BEST', value: '$_bestStreak'),
                        _StreakMetric(label: 'NEXT BONUS', value: '$nextBonus'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StreakMetric extends StatelessWidget {
  const _StreakMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TypographyTokens.labelSmall()),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          value,
          style: TypographyTokens.monolithFont(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: ColorTokens.onSurface,
          ),
        ),
      ],
    );
  }
}
