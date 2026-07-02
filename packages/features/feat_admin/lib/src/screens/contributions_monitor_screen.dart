import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ContributionsMonitorScreen extends ConsumerStatefulWidget {
  const ContributionsMonitorScreen({super.key});

  @override
  ConsumerState<ContributionsMonitorScreen> createState() =>
      _ContributionsMonitorScreenState();
}

class _ContributionsMonitorScreenState
    extends ConsumerState<ContributionsMonitorScreen> {
  final _currency = NumberFormat.decimalPattern();

  List<Map<String, dynamic>> _groups = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _contributions = const <Map<String, dynamic>>[];
  Map<String, String> _aliasMap = const <String, String>{};
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'ALL';
  String _sortMode = 'RECENT';

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonitor());
  }

  Future<void> _loadMonitor() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();

      var groupsQuery = client
          .from('contribution_groups')
          .select(
            'id, name, description, group_type, target_amount, '
            'current_total, member_count, creator_id, '
            'is_closed, created_at',
          );
      groupsQuery = resolver.apply(groupsQuery, scope);
      final groups = List<Map<String, dynamic>>.from(
        ((await groupsQuery.order('created_at', ascending: false)) as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      );
      final groupIds = groups
          .map((group) => group['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      var contributions = const <Map<String, dynamic>>[];
      if (groupIds.isNotEmpty) {
        contributions = List<Map<String, dynamic>>.from(
          (await client
                      .from('group_contributions')
                      .select(
                        'id, group_id, user_id, amount, status, created_at',
                      )
                      .inFilter('group_id', groupIds)
                      .order('created_at', ascending: false)
                      .limit(500)
                  as List)
              .map((row) => Map<String, dynamic>.from(row as Map)),
        );
      }

      final creatorIds = groups
          .map((group) => group['creator_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final aliasMap = <String, String>{};
      if (creatorIds.isNotEmpty) {
        try {
          var profilesQuery = client
              .from('profiles')
              .select('id, public_user_id')
              .inFilter('id', creatorIds);
          profilesQuery = resolver.apply(profilesQuery, scope);
          final profiles = await profilesQuery;
          for (final profile in profiles) {
            final id = profile['id']?.toString();
            final alias = profile['public_user_id']?.toString();
            if (id != null && alias != null && alias.isNotEmpty) {
              aliasMap[id] = alias;
            }
          }
        } catch (error, stackTrace) {
          AfriLogger.warn(
            'ContributionsMonitorScreen',
            'Operation failed (non-critical).',
            error,
            stackTrace,
          );
          // Alias resolution is best-effort for admin reporting.
        }
      }

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _contributions = contributions;
        _aliasMap = aliasMap;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredGroups {
    final filtered = _groups
        .where((group) {
          final type =
              group['group_type']?.toString().toLowerCase() ?? 'community';
          return switch (_selectedFilter) {
            'TEAM PROJECTS' => type == 'project',
            'COMMUNITY' => type == 'community',
            _ => true,
          };
        })
        .toList(growable: false);

    filtered.sort((left, right) {
      if (_sortMode == 'TOTAL') {
        final rightTotal = (right['current_total'] as num?)?.toInt() ?? 0;
        final leftTotal = (left['current_total'] as num?)?.toInt() ?? 0;
        return rightTotal.compareTo(leftTotal);
      }

      final rightDate = DateTime.tryParse(
        right['created_at']?.toString() ?? '',
      );
      final leftDate = DateTime.tryParse(left['created_at']?.toString() ?? '');
      return (rightDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        leftDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    return filtered;
  }

  int get _monthlyTotal {
    final now = DateTime.now();
    return _contributions.fold<int>(0, (sum, contribution) {
      final createdAt = DateTime.tryParse(
        contribution['created_at']?.toString() ?? '',
      );
      final status = contribution['status']?.toString().toLowerCase() ?? '';
      if (createdAt == null ||
          createdAt.year != now.year ||
          createdAt.month != now.month ||
          status == 'failed' ||
          status == 'reversed') {
        return sum;
      }
      return sum + ((contribution['amount'] as num?)?.toInt() ?? 0);
    });
  }

  String _creatorAlias(String? creatorId) {
    final value = creatorId == null ? null : _aliasMap[creatorId];
    return value == null || value.isEmpty ? '000000' : value;
  }

  DateTime? _lastActivityForGroup(String groupId) {
    for (final contribution in _contributions) {
      if (contribution['group_id']?.toString() == groupId) {
        return DateTime.tryParse(contribution['created_at']?.toString() ?? '');
      }
    }
    return null;
  }

  int _contributorCountForGroup(String groupId, int fallbackCount) {
    final users = _contributions
        .where(
          (contribution) => contribution['group_id']?.toString() == groupId,
        )
        .map((contribution) => contribution['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return users.isEmpty ? fallbackCount : users.length;
  }

  Future<void> _exportReport() async {
    final rows = <String>[
      'name,type,total,target,contributors,status,last_activity',
      ..._filteredGroups.map((group) {
        final groupId = group['id']?.toString() ?? '';
        final total = (group['current_total'] as num?)?.toInt() ?? 0;
        final target = (group['target_amount'] as num?)?.toInt() ?? 0;
        final contributorCount = _contributorCountForGroup(
          groupId,
          (group['member_count'] as num?)?.toInt() ?? 0,
        );
        final lastActivity = _lastActivityForGroup(groupId);
        return [
          group['name']?.toString() ?? 'Public group',
          group['group_type']?.toString() ?? 'general',
          '$total',
          '$target',
          '$contributorCount',
          group['is_closed'] == true ? 'closed' : 'active',
          lastActivity?.toIso8601String() ?? '',
        ].map((cell) => '"${cell.replaceAll('"', '""')}"').join(',');
      }),
    ];

    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    AfriToast.success(context, 'Contribution report copied as CSV.');
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.afriCurrencySymbol;
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('CONTRIBUTIONS', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? _AdminMonitorState(
              title: 'Unable to load contributions',
              body: 'Refresh the monitor to try again.',
              actionLabel: 'Retry',
              onPressed: _loadMonitor,
            )
          : AfriRefreshIndicator(
              onRefresh: _loadMonitor,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL RAISED THIS MONTH',
                          style: TypographyTokens.labelSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          '$currencySymbol ${_currency.format(_monthlyTotal)}',
                          style: TypographyTokens.displayMedium(
                            ColorTokens.clubAccent,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          runSpacing: SpacingTokens.spacing2,
                          children: ['ALL', 'TEAM PROJECTS', 'COMMUNITY']
                              .map(
                                (filter) => AfriChoiceChip(
                                  selected: _selectedFilter == filter,
                                  label: Text(filter),
                                  onSelected: (_) =>
                                      setState(() => _selectedFilter = filter),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          children: ['RECENT', 'TOTAL']
                              .map(
                                (mode) => AfriChoiceChip(
                                  selected: _sortMode == mode,
                                  label: Text('SORT $mode'),
                                  onSelected: (_) =>
                                      setState(() => _sortMode = mode),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  if (_filteredGroups.isNotEmpty)
                    ..._filteredGroups.map((group) {
                      final groupId = group['id']?.toString() ?? '';
                      final total =
                          (group['current_total'] as num?)?.toInt() ?? 0;
                      final target =
                          (group['target_amount'] as num?)?.toInt() ?? 0;
                      final memberCount =
                          (group['member_count'] as num?)?.toInt() ?? 0;
                      final lastActivity = _lastActivityForGroup(groupId);
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: GlassCard(
                          animate: false,
                          onTap: groupId.isEmpty
                              ? null
                              : () =>
                                    context.push('/contribute/group/$groupId'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (group['name']?.toString() ??
                                              'Public group')
                                          .toUpperCase(),
                                      style: TypographyTokens.titleLarge()
                                          .copyWith(
                                            color: ColorTokens.onSurface,
                                          ),
                                    ),
                                  ),
                                  _StateChip(
                                    label: group['is_closed'] == true
                                        ? 'CLOSED'
                                        : 'ACTIVE',
                                    active: group['is_closed'] != true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                '${_groupTypeLabel(group['group_type']?.toString())}  •  '
                                'Creator #${_creatorAlias(group['creator_id']?.toString())}',
                                style: TypographyTokens.bodyMedium(),
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                '$currencySymbol ${_currency.format(total)}'
                                '${target > 0 ? ' / $currencySymbol ${_currency.format(target)}' : ''}',
                                style: TypographyTokens.headlineLarge()
                                    .copyWith(color: ColorTokens.clubAccent),
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                '${_contributorCountForGroup(groupId, memberCount)} contributors  •  '
                                '${lastActivity == null ? 'Payment activity pending' : 'Last activity ${DateFormat('dd MMM HH:mm').format(lastActivity.toLocal())}'}',
                                style: TypographyTokens.bodyMedium(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    label: 'Export report',
                    fullWidth: true,
                    onTap: _exportReport,
                    enabled: _filteredGroups.isNotEmpty,
                  ),
                ],
              ),
            ),
    );
  }

  static String _groupTypeLabel(String? value) {
    return switch ((value ?? 'community').toLowerCase()) {
      'project' => 'TEAM PROJECT',
      _ => 'COMMUNITY',
    };
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: active
            ? ColorTokens.clubAccent.withValues(alpha: 0.15)
            : ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TypographyTokens.labelSmall()),
    );
  }
}

class _AdminMonitorState extends StatelessWidget {
  const _AdminMonitorState({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TypographyTokens.headlineMedium().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                label: actionLabel!,
                fullWidth: true,
                onTap: onPressed!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
