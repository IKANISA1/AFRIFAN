import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_providers.dart';

class ChallengeOpsScreen extends ConsumerStatefulWidget {
  const ChallengeOpsScreen({super.key});

  @override
  ConsumerState<ChallengeOpsScreen> createState() => _ChallengeOpsScreenState();
}

class _ChallengeOpsScreenState extends ConsumerState<ChallengeOpsScreen> {
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final statuses = switch (_filter) {
        'locked' => const <String>['locked'],
        'open' => const <String>['open'],
        'settled' => const <String>['settled'],
        'void' => const <String>['void', 'cancelled'],
        _ => null,
      };
      final items = await ref
          .read(adminRepositoryProvider)
          .getPredictionChallenges(statuses: statuses);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _retrySettlement(String challengeId) async {
    final result = await ref
        .read(adminRepositoryProvider)
        .retryPredictionChallengeSettlement(challengeId);
    if (!mounted) {
      return;
    }
    final isError = result['status']?.toString() == 'error';
    final message = isError
        ? result['message']?.toString() ?? 'Retry failed.'
        : 'Settlement retry executed.';
    if (isError) {
      AfriToast.error(context, message);
    } else {
      AfriToast.success(context, message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'CHALLENGE OPS',
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
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.error(
                title: 'Challenge ops unavailable',
                message: _error!,
                actionLabel: 'Retry',
                onAction: () => unawaited(_load()),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children:
                        const <String>[
                          'all',
                          'open',
                          'locked',
                          'settled',
                          'void',
                        ].map((filter) {
                          return AfriChoiceChip(
                            selected: _filter == filter,
                            label: Text(filter.toUpperCase()),
                            onSelected: (_) {
                              setState(() => _filter = filter);
                              unawaited(_load());
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  if (_items.isNotEmpty) ..._items.map(_buildCard),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> row) {
    final fixture = _jsonMap(row['fixture']);
    final settlement = _jsonMap(row['settlement']);
    final admin = _jsonMap(row['admin']);
    final challengeId = row['id']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'open';
    final canRetry = status == 'locked';

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fixture['competition_name']?.toString() ?? 'Challenge',
                    style: TypographyTokens.titleSmall(),
                  ),
                ),
                _OpsChip(label: status.toUpperCase()),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              '${fixture['home_team_short_name'] ?? 'HOME'} vs ${fixture['away_team_short_name'] ?? 'AWAY'}',
              style: TypographyTokens.titleMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Creator ${row['creator_name'] ?? 'Supporter'} • '
              'Pool ${row['total_pool_fet'] ?? 0} FET • '
              'Participants ${row['total_participants'] ?? 0}',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurfaceVariant),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                _OpsChip(
                  label: 'Void ${row['void_reason']?.toString() ?? 'none'}',
                ),
                _OpsChip(
                  label:
                      'Settlement ${settlement['settlement_mode']?.toString() ?? admin['settlement_mode']?.toString() ?? 'pending'}',
                ),
                _OpsChip(
                  label:
                      'Audit ${admin['settlement_state']?.toString() ?? 'pending'}',
                ),
              ],
            ),
            if (canRetry) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                label: 'RETRY SETTLEMENT',
                icon: AfriIcons.refresh,
                variant: AfriButtonVariant.secondary,
                onTap: () => _retrySettlement(challengeId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }
}

class _OpsChip extends StatelessWidget {
  const _OpsChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: ShapeTokens.buttonRadius,
      ),
      child: Text(label, style: TypographyTokens.labelSmall()),
    );
  }
}
