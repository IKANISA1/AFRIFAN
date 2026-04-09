import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/contribution_overlays.dart';

int? _currentClubId(SupabaseClient client) {
  final user = client.auth.currentUser;
  final candidates = <Object?>[
    user?.appMetadata['club_id'],
    user?.userMetadata?['club_id'],
    user?.appMetadata['clubId'],
    user?.userMetadata?['clubId'],
  ];

  for (final candidate in candidates) {
    final parsed = int.tryParse(candidate?.toString().trim() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

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
  final _currency = CurrencyFormatter(
    currencyCode: 'RWF',
    currencySymbol: 'FRw',
  );

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Could not resolve the active club.';
          });
        }
        return;
      }
      final groupRow = await client
          .from('contribution_groups')
          .select()
          .eq('id', widget.groupId)
          .eq('club_id', clubId)
          .maybeSingle();

      if (groupRow == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Circle not found';
          });
        }
        return;
      }

      final contributions = await client
          .from('contributions')
          .select('user_id, amount, created_at, status')
          .eq('group_id', widget.groupId)
          .order('created_at', ascending: false)
          .limit(20);

      final userIds = contributions
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList(growable: false);

      final aliases = <String, String>{};
      if (userIds.isNotEmpty) {
        final profiles = await client
            .from('profiles')
            .select('id, public_user_id')
            .inFilter('id', userIds);
        for (final profile in profiles) {
          aliases[profile['id']?.toString() ?? ''] =
              profile['public_user_id']?.toString() ?? '000000';
        }
      }

      if (!mounted) return;

      setState(() {
        _group = Map<String, dynamic>.from(groupRow);
        _ledger = contributions
            .map((entry) {
              final userId = entry['user_id']?.toString() ?? '';
              final alias = aliases[userId] ?? '000000';
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
          _error = 'Could not load this circle.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final currentTotal = (group?['current_total'] as num?)?.toInt() ?? 0;
    final targetAmount = (group?['target_amount'] as num?)?.toInt() ?? 0;
    final progress = targetAmount > 0
        ? (currentTotal / targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final title = group?['name']?.toString() ?? 'CIRCLE';
    final description = group?['description']?.toString();
    final privacy = group?['privacy']?.toString() ?? 'private';
    final memberCount = (group?['member_count'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          title.toUpperCase(),
          style: GoogleFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => showGroupInviteCodeSheet(
              context,
              inviteCode: group?['invite_code']?.toString(),
              groupName: title,
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing4),
              child: AfriSkeletonList(),
            )
          : _error != null || group == null
          ? _GroupState(
              title: _error ?? 'Circle unavailable',
              body: 'Try returning to your circles and opening it again.',
              onPressed: () => context.go('/contribute/groups'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: Column(
                children: [
                  GlassCard(
                    animate: false,
                    child: Column(
                      children: [
                        Text(
                          _currency.format(currentTotal),
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: ColorTokens.clubAccent,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing1),
                        Text(
                          'Target ${_currency.format(targetAmount)}  •  ${(progress * 100).round()}%',
                          style: TypographyTokens.bodyMedium(),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: SpacingTokens.spacing3),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: TypographyTokens.bodyMedium(),
                          ),
                        ],
                        const SizedBox(height: SpacingTokens.spacing4),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor: ColorTokens.surfaceContainerHighest,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _GroupMetaStat(
                              label: 'PRIVACY',
                              value: privacy.toUpperCase(),
                            ),
                            _GroupMetaStat(
                              label: 'MEMBERS',
                              value: '$memberCount',
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing5),
                        ClaymorphicButton(
                          label: 'CONTRIBUTE NOW',
                          width: double.infinity,
                          onPressed: () => showMomoAmountEntrySheet(
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
                  const SizedBox(height: SpacingTokens.spacing4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push(
                            '/contribute/group/${widget.groupId}/chat',
                          ),
                          child: const Text('CHAT'),
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push(
                            '/contribute/group/${widget.groupId}/settings',
                          ),
                          child: const Text('SETTINGS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'LEDGER',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ColorTokens.onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => showAfriFilterSortSheet(
                          context: context,
                          title: 'Ledger Filters',
                          sortOptions: const [
                            AfriFilterOption(value: 'newest', label: 'Newest'),
                            AfriFilterOption(value: 'oldest', label: 'Oldest'),
                            AfriFilterOption(
                              value: 'amount_high',
                              label: 'Amount High',
                            ),
                            AfriFilterOption(
                              value: 'amount_low',
                              label: 'Amount Low',
                            ),
                          ],
                          typeOptions: const [
                            AfriFilterOption(
                              value: 'contributions',
                              label: 'Contributions',
                            ),
                            AfriFilterOption(
                              value: 'receipts',
                              label: 'Receipts',
                            ),
                          ],
                          showDateRange: true,
                          showAmountRange: true,
                        ),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  if (_ledger.isEmpty)
                    GlassCard(
                      animate: false,
                      child: Text(
                        'No contributions have been recorded for this circle yet.',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ),
                  ..._ledger.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: SpacingTokens.spacing3,
                      ),
                      child: _LedgerRow(
                        alias: entry['alias']?.toString() ?? '#------',
                        amount: _currency.format(
                          (entry['amount'] as num?)?.toInt() ?? 0,
                        ),
                        time:
                            '${entry['time']?.toString() ?? 'just now'}  •  ${(entry['status']?.toString() ?? 'pending').toUpperCase()}',
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
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
              Icons.group_work_outlined,
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
            ClaymorphicButton(label: 'Back to Circles', onPressed: onPressed),
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
          Expanded(
            child: Text(
              alias,
              style: TypographyTokens.numericAlias(fontSize: 15),
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorTokens.clubAccent,
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing4),
          Text(time, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}
