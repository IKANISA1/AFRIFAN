import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/contribution_overlays.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
    currencyCode: context.afriCurrencyCode,
    currencySymbol: context.afriCurrencySymbol,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroup());
  }

  Future<void> _loadGroup() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      if (scope.clubId == null) {
        throw StateError('Contribution Groups require a numeric club scope.');
      }
      final groupRow = await client
          .from('contribution_groups')
          .select()
          .eq('id', widget.groupId)
          .eq('club_id', scope.clubId!)
          .maybeSingle();

      if (groupRow == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Group not found';
          });
        }
        return;
      }

      final contributions = await client
          .from('group_contributions')
          .select('user_id, amount, created_at, status, momo_reference')
          .eq('group_id', widget.groupId)
          .order('created_at', ascending: false)
          .limit(20);

      final userIds = contributions
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);

      final aliasMap = <String, String>{};
      if (userIds.isNotEmpty) {
        final profiles = await client
            .from('profiles')
            .select('id, public_user_id')
            .inFilter('id', userIds);
        for (final profile in profiles) {
          aliasMap[profile['id']?.toString() ?? ''] =
              profile['public_user_id']?.toString() ?? '000000';
        }
      }

      if (!mounted) return;

      setState(() {
        _group = Map<String, dynamic>.from(groupRow);
        _ledger = contributions
            .map((entry) {
              final userId = entry['user_id']?.toString() ?? '';
              final alias = aliasMap[userId] ?? '000000';
              return <String, dynamic>{
                'alias': '#$alias',
                'amount': (entry['amount'] as num?)?.toInt() ?? 0,
                'status': entry['status']?.toString() ?? 'pending',
                'time': AfriDateFormatter.timeAgo(
                  DateTime.tryParse(entry['created_at']?.toString() ?? '') ??
                      DateTime.now(),
                ),
              };
            })
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this public initiative right now.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = _currencyFormatter;
    final group = _group;
    final currentTotal = (group?['current_total'] as num?)?.toInt() ?? 0;
    final targetAmount = (group?['target_amount'] as num?)?.toInt() ?? 0;
    final progress = targetAmount > 0
        ? (currentTotal / targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final title = group?['name']?.toString() ?? 'Public initiative';
    final description = group?['description']?.toString();
    final groupType = (group?['group_type']?.toString() ?? 'community')
        .replaceAll('_', ' ')
        .toUpperCase();
    final memberCount = (group?['member_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          title.toUpperCase(),
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/contribute/groups');
            }
          },
        ),
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing4),
              child: AfriSkeletonList(),
            )
          : _error != null || group == null
          ? _GroupState(
              title: _error ?? 'Initiative unavailable',
              body:
                  'Try returning to the communities list and opening it again.',
              onPressed: () => context.go('/contribute/groups'),
            )
          : AfriRefreshIndicator(
              onRefresh: _loadGroup,
              color: ColorTokens.clubAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: Column(
                  children: [
                    GlassCard(
                      animate: false,
                      child: Column(
                        children: [
                          Text(
                            currency.format(currentTotal),
                            style: TypographyTokens.displayLarge(
                              ColorTokens.clubAccent,
                            ).copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: SpacingTokens.spacing1),
                          Text(
                            'Target ${currency.format(targetAmount)}  •  ${(progress * 100).round()}%',
                            style: TypographyTokens.bodyMedium(),
                          ),
                          if (description != null &&
                              description.isNotEmpty) ...[
                            const SizedBox(height: SpacingTokens.spacing3),
                            Text(
                              description,
                              textAlign: TextAlign.center,
                              style: TypographyTokens.bodyMedium(),
                            ),
                          ],
                          const SizedBox(height: SpacingTokens.spacing4),
                          AfriLinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            borderRadius: ShapeTokens.buttonRadius,
                            color: ColorTokens.clubAccent,
                            backgroundColor:
                                ColorTokens.surfaceContainerHighest,
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _GroupMetaStat(label: 'TYPE', value: groupType),
                              _GroupMetaStat(
                                label: 'CONTRIBUTORS',
                                value: '$memberCount',
                              ),
                            ],
                          ),
                          const SizedBox(height: SpacingTokens.spacing5),
                          AfriButton(
                            label: 'Contribute now',
                            fullWidth: true,
                            onTap: () => showMomoAmountEntrySheet(
                              context,
                              title: title,
                              groupId: widget.groupId,
                              recipientMomo:
                                  group['momo_recipient_code']?.toString() ??
                                  group['receiving_momo_code']?.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GroupLedgerSection(
                      ledger: _ledger,
                      currencyFormatter: currency,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class GroupLedgerSection extends StatelessWidget {
  const GroupLedgerSection({
    required this.ledger,
    required this.currencyFormatter,
    super.key,
  });

  final List<Map<String, dynamic>> ledger;
  final CurrencyFormatter currencyFormatter;

  @override
  Widget build(BuildContext context) {
    if (ledger.isEmpty) {
      return const SizedBox.shrink(key: ValueKey<String>('group-ledger-empty'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SpacingTokens.spacing6),
        Row(
          children: [
            Expanded(
              child: Text(
                'LEDGER',
                style: TypographyTokens.titleLarge().copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...ledger.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
            child: _LedgerRow(
              alias: entry['alias']?.toString() ?? '#------',
              amount: currencyFormatter.format(
                (entry['amount'] as num?)?.toInt() ?? 0,
              ),
              time:
                  '${entry['time']?.toString() ?? 'just now'}  •  ${humanizeContributionStatus(entry['status']?.toString())}',
            ),
          );
        }),
      ],
    );
  }
}

String humanizeContributionStatus(String? raw) {
  return switch (raw?.toLowerCase().trim()) {
    'confirmed' => 'CONFIRMED',
    'rejected' || 'failed' => 'FAILED',
    'pending' || '' || null => 'PROCESSING',
    final other => other.toUpperCase(),
  };
}

class _GroupMetaStat extends StatelessWidget {
  const _GroupMetaStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TypographyTokens.labelSmall()),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(value, style: TypographyTokens.labelLarge()),
      ],
    );
  }
}

class _GroupState extends StatelessWidget {
  const _GroupState({
    required this.title,
    required this.body,
    required this.onPressed,
  });

  final String title;
  final String body;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AfriIcons.groups,
              size: 56,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(title, style: TypographyTokens.headlineSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            AfriButton(label: 'Back to communities', onTap: onPressed),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.alias,
    required this.amount,
    required this.time,
  });

  final String alias;
  final String amount;
  final String time;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Row(
        children: [
          Expanded(child: Text(alias, style: TypographyTokens.titleMedium())),
          Text(
            amount,
            style: TypographyTokens.headlineMedium(
              ColorTokens.clubAccent,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Text(time, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}
