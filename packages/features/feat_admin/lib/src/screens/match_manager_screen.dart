import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../widgets/match_composer_sheet.dart';

class MatchManagerScreen extends ConsumerStatefulWidget {
  const MatchManagerScreen({super.key});

  @override
  ConsumerState<MatchManagerScreen> createState() => _MatchManagerScreenState();
}

class _MatchManagerScreenState extends ConsumerState<MatchManagerScreen> {
  final _currency = NumberFormat.decimalPattern();

  List<Map<String, dynamic>> _matches = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  String _filter = 'ALL';
  String? _partnerId;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final rows = await ref
          .read(supabaseClientProvider)
          .from('matches')
          .select()
          .order('match_date', ascending: true);

      if (!mounted) return;
      final matches = List<Map<String, dynamic>>.from(rows);
      setState(() {
        _matches = matches;
        _partnerId = matches.isEmpty
            ? null
            : matches.first['partner_id']?.toString();
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

  List<Map<String, dynamic>> get _filteredMatches {
    final now = DateTime.now();
    return _matches
        .where((match) {
          final matchDate = DateTime.tryParse(
            match['match_date']?.toString() ?? '',
          );
          final isUpcoming = matchDate == null
              ? true
              : !matchDate.isBefore(DateTime(now.year, now.month, now.day));
          final status = match['match_status']?.toString().trim().toLowerCase();
          return switch (_filter) {
            'LIVE' => status == 'live' || status == 'halftime',
            'UPCOMING' => isUpcoming,
            'COMPLETED' => !isUpcoming,
            'ON SALE' => match['is_on_sale'] == true,
            _ => true,
          };
        })
        .toList(growable: false);
  }

  Future<void> _openComposer([Map<String, dynamic>? existing]) async {
    final saved = await showMatchComposerSheet(
      context,
      ref: ref,
      existing: existing,
      partnerId: _partnerId,
    );

    if (saved == true) {
      await _loadMatches();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Match created successfully.'
                : 'Match updated successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.afriCurrencySymbol;
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('MATCHES', style: TypographyTokens.titleLarge()),
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
          ? _StateCard(
              title: 'Unable to load fixtures',
              body: 'Refresh the match manager to try again.',
              actionLabel: 'Retry',
              onPressed: _loadMatches,
            )
          : RefreshIndicator(
              onRefresh: _loadMatches,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children:
                        ['ALL', 'LIVE', 'UPCOMING', 'ON SALE', 'COMPLETED']
                            .map(
                              (filter) => ChoiceChip(
                                selected: _filter == filter,
                                label: Text(filter),
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  if (_filteredMatches.isEmpty)
                    const _StateCard(
                      title: 'No fixtures in this view',
                      body:
                          'Create a new match or switch filters to inspect the live schedule.',
                      actionLabel: null,
                    )
                  else
                    ..._filteredMatches.map((match) {
                      final matchDate = DateTime.tryParse(
                        match['match_date']?.toString() ?? '',
                      );
                      final soldCount =
                          (match['sold_count'] as num?)?.toInt() ?? 0;
                      final capacity =
                          (match['capacity'] as num?)?.toInt() ?? 0;
                      final homeScore =
                          (match['home_score'] as num?)?.toInt() ?? 0;
                      final awayScore =
                          (match['away_score'] as num?)?.toInt() ?? 0;
                      final liveMinute =
                          (match['live_minute'] as num?)?.toInt() ?? 0;
                      final isUpcoming = matchDate == null
                          ? true
                          : !matchDate.isBefore(
                              DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                DateTime.now().day,
                              ),
                            );
                      final matchStatus = _statusLabel(
                        match['match_status']?.toString(),
                        isUpcoming,
                      );
                      final liveMinuteLabel =
                          (matchStatus == 'LIVE' ||
                                  matchStatus == 'HALF-TIME') &&
                              liveMinute > 0
                          ? "  •  ${liveMinute.toString()}'"
                          : '';
                      final soldPercent = capacity <= 0
                          ? 0
                          : ((soldCount / capacity) * 100).round();
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: GlassCard(
                          animate: false,
                          onTap: () => _openComposer(match),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${match['home_team']} vs ${match['away_team']}'
                                          .toUpperCase(),
                                      style: TypographyTokens.titleLarge()
                                          .copyWith(
                                            color: ColorTokens.onSurface,
                                          ),
                                    ),
                                  ),
                                  _MatchChip(
                                    label: matchStatus,
                                    color: switch (matchStatus) {
                                      'LIVE' => ColorTokens.success,
                                      'HALF-TIME' => ColorTokens.clubAccent,
                                      'FULL-TIME' =>
                                        ColorTokens.surfaceContainerHigh,
                                      'POSTPONED' => ColorTokens.error,
                                      'CANCELLED' => ColorTokens.error,
                                      _ => ColorTokens.clubAccent,
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                '${match['competition']}  •  ${match['venue']}',
                                style: TypographyTokens.bodyMedium(),
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                '${matchDate == null ? 'Date pending' : DateFormat('dd MMM yyyy').format(matchDate)}'
                                '  •  ${_formatKickoff(match['kickoff_time']?.toString())}',
                                style: TypographyTokens.bodyMedium(),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              Text(
                                'GENERAL $currencySymbol ${_currency.format((match['ticket_general_price'] as num?)?.toInt() ?? 0)}'
                                '  •  VIP $currencySymbol ${_currency.format((match['ticket_vip_price'] as num?)?.toInt() ?? 0)}',
                                style: TypographyTokens.bodyMedium(),
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                'Score $homeScore-$awayScore$liveMinuteLabel',
                                style: TypographyTokens.bodyMedium(),
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                '$soldPercent% allocation  •  $soldCount / $capacity tickets',
                                style: TypographyTokens.bodyMedium(),
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _openComposer(match),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: Text(
                                    match['is_on_sale'] == true
                                        ? 'EDIT ON-SALE FIXTURE'
                                        : 'EDIT FIXTURE',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ClaymorphicButton(
                    label: 'CREATE MATCH',
                    width: double.infinity,
                    onPressed: _openComposer,
                  ),
                ],
              ),
            ),
    );
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  static String _formatKickoff(String? value) {
    final time = _parseTime(value);
    if (time == null) return 'Kickoff pending';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _statusLabel(String? rawValue, bool isUpcoming) {
    final value = rawValue?.trim().toLowerCase() ?? '';
    return switch (value) {
      'live' => 'LIVE',
      'halftime' => 'HALF-TIME',
      'fulltime' => 'FULL-TIME',
      'postponed' => 'POSTPONED',
      'cancelled' => 'CANCELLED',
      _ => isUpcoming ? 'UPCOMING' : 'COMPLETED',
    };
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TypographyTokens.labelSmall()),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
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
              ClaymorphicButton(
                label: actionLabel!,
                width: double.infinity,
                onPressed: onPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
