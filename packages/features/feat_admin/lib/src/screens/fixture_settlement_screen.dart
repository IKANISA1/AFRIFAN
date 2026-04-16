import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Admin screen for viewing prediction fixtures, entering match results,
/// and triggering one-click settlement via `prediction_admin_settle`.
class FixtureSettlementScreen extends ConsumerStatefulWidget {
  const FixtureSettlementScreen({super.key});

  @override
  ConsumerState<FixtureSettlementScreen> createState() =>
      _FixtureSettlementScreenState();
}

class _FixtureSettlementScreenState
    extends ConsumerState<FixtureSettlementScreen> {
  List<Map<String, dynamic>> _fixtures = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'scheduled';

  @override
  void initState() {
    super.initState();
    _loadFixtures();
  }

  Future<void> _loadFixtures() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final baseQuery = client
          .schema('football')
          .from('fixtures')
          .select('''
            id, status, stage_name, group_name,
            kickoff_at, venue_city, venue_country,
            home_score, away_score,
            home_team:teams!fixtures_home_team_id_fkey(id, name, short_name),
            away_team:teams!fixtures_away_team_id_fkey(id, name, short_name),
            competition:competitions!fixtures_competition_id_fkey(name, short_name)
          ''');

      final filteredQuery = _statusFilter != 'all'
          ? baseQuery.eq('status', _statusFilter)
          : baseQuery;

      final rows = await filteredQuery
          .order('kickoff_at', ascending: true)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _fixtures = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _settleFixture(Map<String, dynamic> fixture) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorTokens.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SettlementSheet(fixture: fixture),
    );

    if (result == null) return;

    if (!mounted) return;

    // Show loading
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final params = <String, dynamic>{
        'p_fixture_id': fixture['id'],
        'p_home_score': result['home_score'],
        'p_away_score': result['away_score'],
        'p_status': result['status'],
      };
      if (result['ht_home_score'] != null) {
        params['p_ht_home_score'] = result['ht_home_score'];
        params['p_ht_away_score'] = result['ht_away_score'];
      }

      final rpcResult = await SafeRpc.call(
        'prediction_admin_settle',
        params: params,
        tag: 'AdminSettle',
        maxAttempts: 1, // Don't retry writes.
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      if (!rpcResult.isSuccess || rpcResult.data is! Map) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settlement failed: ${rpcResult.error ?? 'Unexpected response'}',
            ),
            backgroundColor: ColorTokens.error,
          ),
        );
        return;
      }

      final responseMap = Map<String, dynamic>.from(rpcResult.data as Map);
      final settlementData =
          responseMap['settlement'] as Map<String, dynamic>? ?? {};
      final marketsProcessed =
          (responseMap['markets_settled'] as num?)?.toInt() ?? 0;
      final totalWon =
          (settlementData['total_won'] as num?)?.toInt() ?? 0;
      final totalLost =
          (settlementData['total_lost'] as num?)?.toInt() ?? 0;

      await _loadFixtures();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settled! $marketsProcessed markets • '
            '$totalWon won • $totalLost lost',
          ),
          backgroundColor: ColorTokens.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settlement failed: $e'),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('SETTLE FIXTURES', style: TypographyTokens.titleLarge()),
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
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadFixtures,
                  child: ListView(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    children: [
                      _buildFilterChips(),
                      const SizedBox(height: SpacingTokens.spacing4),
                      if (_fixtures.isEmpty)
                        _buildEmpty()
                      else
                        ..._fixtures.map(_buildFixtureCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterChips() {
    const filters = <String, String>{
      'scheduled': 'SCHEDULED',
      'finished': 'FINISHED',
      'all': 'ALL',
    };
    return Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: filters.entries
          .map(
            (e) => ChoiceChip(
              selected: _statusFilter == e.key,
              label: Text(e.value),
              onSelected: (_) {
                setState(() => _statusFilter = e.key);
                _loadFixtures();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildFixtureCard(Map<String, dynamic> fixture) {
    final homeTeam = fixture['home_team'] as Map<String, dynamic>? ?? {};
    final awayTeam = fixture['away_team'] as Map<String, dynamic>? ?? {};
    final competition = fixture['competition'] as Map<String, dynamic>? ?? {};
    final status = fixture['status']?.toString() ?? 'scheduled';
    final kickoff = DateTime.tryParse(fixture['kickoff_at']?.toString() ?? '');
    final homeScore = (fixture['home_score'] as num?)?.toInt();
    final awayScore = (fixture['away_score'] as num?)?.toInt();
    final isSettled = status == 'finished' || status == 'cancelled';

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Competition + status
            Row(
              children: [
                Expanded(
                  child: Text(
                    competition['short_name']?.toString() ??
                        competition['name']?.toString() ??
                        '',
                    style: TypographyTokens.labelSmall(),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),

            // Teams + Score
            Row(
              children: [
                Expanded(
                  child: Text(
                    homeTeam['name']?.toString() ?? 'TBD',
                    style: TypographyTokens.titleLarge().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                ),
                if (homeScore != null && awayScore != null)
                  Text(
                    '$homeScore - $awayScore',
                    style: TypographyTokens.headlineMedium().copyWith(
                      color: ColorTokens.clubAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    'vs',
                    style: TypographyTokens.titleMedium().copyWith(
                      color: ColorTokens.onSurfaceVariant,
                    ),
                  ),
                Expanded(
                  child: Text(
                    awayTeam['name']?.toString() ?? 'TBD',
                    textAlign: TextAlign.end,
                    style: TypographyTokens.titleLarge().copyWith(
                      color: ColorTokens.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing2),

            // Date + Venue
            Text(
              '${kickoff != null ? DateFormat('dd MMM yyyy, HH:mm').format(kickoff.toLocal()) : 'Date TBD'}'
              '${fixture['venue_city'] != null ? '  •  ${fixture['venue_city']}' : ''}',
              style: TypographyTokens.bodyMedium(),
            ),

            if (fixture['stage_name'] != null || fixture['group_name'] != null)
              Padding(
                padding: const EdgeInsets.only(top: SpacingTokens.spacing1),
                child: Text(
                  [fixture['stage_name'], fixture['group_name']]
                      .where((v) => v != null)
                      .join('  •  '),
                  style: TypographyTokens.bodySmall(),
                ),
              ),

            const SizedBox(height: SpacingTokens.spacing3),

            // Settle button
            if (!isSettled)
              Align(
                alignment: Alignment.centerRight,
                child: AfriButton(
                  label: 'Enter result',
                  onTap: () => _settleFixture(fixture),
                  fullWidth: false,
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: ColorTokens.success,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Text(
                      'SETTLED',
                      style: TypographyTokens.labelSmall().copyWith(
                        color: ColorTokens.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_score_rounded,
              size: 48,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'No fixtures found',
              style: TypographyTokens.headlineMedium().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Switch filters or wait for fixtures to be added.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: ColorTokens.error,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'Failed to load fixtures',
              style: TypographyTokens.headlineMedium().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: 'Retry',
              fullWidth: true,
              onTap: _loadFixtures,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settlement Bottom Sheet ──

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet({required this.fixture});

  final Map<String, dynamic> fixture;

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _homeScoreController = TextEditingController(text: '0');
  final _awayScoreController = TextEditingController(text: '0');
  final _htHomeScoreController = TextEditingController();
  final _htAwayScoreController = TextEditingController();
  String _status = 'finished';
  bool _showHtScore = false;

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _htHomeScoreController.dispose();
    _htAwayScoreController.dispose();
    super.dispose();
  }

  void _submit() {
    final homeScore = int.tryParse(_homeScoreController.text) ?? 0;
    final awayScore = int.tryParse(_awayScoreController.text) ?? 0;
    final htHome = int.tryParse(_htHomeScoreController.text);
    final htAway = int.tryParse(_htAwayScoreController.text);

    Navigator.of(context).pop(<String, dynamic>{
      'home_score': homeScore,
      'away_score': awayScore,
      'status': _status,
      if (htHome != null && htAway != null) ...{
        'ht_home_score': htHome,
        'ht_away_score': htAway,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam = widget.fixture['home_team'] as Map<String, dynamic>? ?? {};
    final awayTeam = widget.fixture['away_team'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: EdgeInsets.only(
        left: SpacingTokens.spacing6,
        right: SpacingTokens.spacing6,
        top: SpacingTokens.spacing6,
        bottom: MediaQuery.of(context).viewInsets.bottom + SpacingTokens.spacing6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          Text(
            'ENTER RESULT',
            style: TypographyTokens.titleLarge().copyWith(
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${homeTeam['name'] ?? 'Home'} vs ${awayTeam['name'] ?? 'Away'}',
            style: TypographyTokens.bodyLarge(),
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // Score inputs
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      homeTeam['short_name']?.toString() ?? 'HOME',
                      style: TypographyTokens.labelSmall()
                          .copyWith(letterSpacing: 1),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    TextField(
                      controller: _homeScoreController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TypographyTokens.displaySmall(
                        ColorTokens.clubAccent,
                      ),
                      decoration: InputDecoration(
                        border: BorderTokens.input(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: ColorTokens.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing4,
                ),
                child: Text(
                  '—',
                  style: TypographyTokens.headlineLarge().copyWith(
                    color: ColorTokens.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      awayTeam['short_name']?.toString() ?? 'AWAY',
                      style: TypographyTokens.labelSmall()
                          .copyWith(letterSpacing: 1),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    TextField(
                      controller: _awayScoreController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TypographyTokens.displaySmall(
                        ColorTokens.clubAccent,
                      ),
                      decoration: InputDecoration(
                        border: BorderTokens.input(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: ColorTokens.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),

          // Half-time score toggle
          GestureDetector(
            onTap: () => setState(() => _showHtScore = !_showHtScore),
            child: Row(
              children: [
                Icon(
                  _showHtScore
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: ColorTokens.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                Text(
                  'HALF-TIME SCORE (optional)',
                  style: TypographyTokens.labelSmall()
                      .copyWith(letterSpacing: 1),
                ),
              ],
            ),
          ),
          if (_showHtScore) ...[
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _htHomeScoreController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.titleLarge(),
                    decoration: InputDecoration(
                      hintText: 'HT',
                      border: BorderTokens.input(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: ColorTokens.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: SpacingTokens.spacing3,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing3,
                  ),
                  child: Text(
                    '—',
                    style: TypographyTokens.titleLarge().copyWith(
                      color: ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _htAwayScoreController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.titleLarge(),
                    decoration: InputDecoration(
                      hintText: 'HT',
                      border: BorderTokens.input(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: ColorTokens.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: SpacingTokens.spacing3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: SpacingTokens.spacing5),

          // Status selector
          Text(
            'STATUS',
            style: TypographyTokens.labelSmall().copyWith(letterSpacing: 1),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Wrap(
            spacing: SpacingTokens.spacing2,
            children: ['finished', 'cancelled', 'postponed']
                .map(
                  (s) => ChoiceChip(
                    selected: _status == s,
                    label: Text(s.toUpperCase()),
                    onSelected: (_) => setState(() => _status = s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: SpacingTokens.spacing6),

          // Settle button
          AfriButton(
            label: _status == 'finished'
                ? 'Settle & grade predictions'
                : 'Update status',
            fullWidth: true,
            onTap: _submit,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
        ],
      ),
    );
  }
}

// ── Status Chip ──

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'finished' => ColorTokens.success,
      'scheduled' => ColorTokens.clubAccent,
      'cancelled' => ColorTokens.error,
      'postponed' => ColorTokens.error,
      _ => ColorTokens.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TypographyTokens.labelSmall().copyWith(color: color),
      ),
    );
  }
}
