import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part '../widgets/competitions/competition_widgets.dart';

/// Admin screen for managing supported competitions and seasons.
///
/// Provides CRUD: list / add / edit / toggle active / manage seasons.
/// Competitions drive which matches appear in the prediction engine.
class CompetitionManagerScreen extends ConsumerStatefulWidget {
  const CompetitionManagerScreen({super.key});

  @override
  ConsumerState<CompetitionManagerScreen> createState() =>
      _CompetitionManagerScreenState();
}

class _CompetitionManagerScreenState
    extends ConsumerState<CompetitionManagerScreen> {
  List<Map<String, dynamic>> _competitions = const [];
  bool _isLoading = true;
  String? _error;
  String _regionFilter = 'all';
  String _kindFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCompetitions();
  }

  Future<void> _loadCompetitions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      var query = client.schema('football').from('competitions').select('''
        id, slug, name, short_name, competition_kind,
        region, country_code, country_name, organizer,
        gender, format_notes, is_active, metadata,
        created_at, updated_at
      ''');

      if (_regionFilter != 'all') {
        query = query.eq('region', _regionFilter);
      }
      if (_kindFilter != 'all') {
        query = query.eq('competition_kind', _kindFilter);
      }

      final rows = await query.order('name', ascending: true);
      if (!mounted) return;
      setState(() {
        _competitions = List<Map<String, dynamic>>.from(rows);
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

  Future<void> _toggleActive(Map<String, dynamic> competition) async {
    final id = competition['id']?.toString();
    final currentlyActive = competition['is_active'] == true;
    if (id == null) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .schema('football')
          .from('competitions')
          .update({'is_active': !currentlyActive})
          .eq('id', id);

      await _loadCompetitions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive
                ? '${competition['name']} deactivated'
                : '${competition['name']} activated',
          ),
          backgroundColor: currentlyActive
              ? ColorTokens.error
              : ColorTokens.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  Future<void> _openCompetitionForm([Map<String, dynamic>? existing]) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorTokens.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CompetitionFormSheet(existing: existing),
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
      final client = ref.read(supabaseClientProvider);

      if (existing != null) {
        // Update
        await client
            .schema('football')
            .from('competitions')
            .update(result)
            .eq('id', existing['id']);
      } else {
        // Insert
        await client.schema('football').from('competitions').insert(result);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      await _loadCompetitions();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing != null ? 'Competition updated' : 'Competition created',
          ),
          backgroundColor: ColorTokens.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  Future<void> _openSeasonManager(Map<String, dynamic> competition) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorTokens.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SeasonManagerSheet(
        competitionId: competition['id'].toString(),
        competitionName: competition['name']?.toString() ?? '',
        supabaseClient: ref.read(supabaseClientProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _competitions
        .where((c) => c['is_active'] == true)
        .length;
    final totalCount = _competitions.length;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('COMPETITIONS', style: TypographyTokens.titleLarge()),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
        actions: [
          IconButton(
            onPressed: () => _openCompetitionForm(),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add competition',
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadCompetitions,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  // Stats row
                  _buildStatsRow(activeCount, totalCount),
                  const SizedBox(height: SpacingTokens.spacing4),

                  // Region filter
                  _buildRegionFilter(),
                  const SizedBox(height: SpacingTokens.spacing2),

                  // Kind filter
                  _buildKindFilter(),
                  const SizedBox(height: SpacingTokens.spacing4),

                  if (_competitions.isEmpty)
                    _buildEmpty()
                  else
                    ..._competitions.map(_buildCompetitionCard),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow(int active, int total) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: ColorTokens.onSurfaceVariant,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Text('TOTAL', style: TypographyTokens.labelSmall()),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '$total',
                  style: TypographyTokens.headlineLarge().copyWith(
                    color: ColorTokens.clubAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: GlassCard(
            animate: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: ColorTokens.success,
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Text('ACTIVE', style: TypographyTokens.labelSmall()),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  '$active',
                  style: TypographyTokens.headlineLarge().copyWith(
                    color: ColorTokens.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegionFilter() {
    const regions = <String, String>{
      'all': 'ALL',
      'africa': 'AFRICA',
      'europe': 'EUROPE',
      'international': 'INTL',
    };
    return Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: regions.entries
          .map(
            (e) => ChoiceChip(
              selected: _regionFilter == e.key,
              label: Text(e.value),
              onSelected: (_) {
                setState(() => _regionFilter = e.key);
                _loadCompetitions();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildKindFilter() {
    const kinds = <String, String>{
      'all': 'ALL',
      'league': 'LEAGUE',
      'cup': 'CUP',
      'tournament': 'TOURNAMENT',
    };
    return Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: kinds.entries
          .map(
            (e) => ChoiceChip(
              selected: _kindFilter == e.key,
              label: Text(e.value),
              onSelected: (_) {
                setState(() => _kindFilter = e.key);
                _loadCompetitions();
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildCompetitionCard(Map<String, dynamic> competition) {
    final isActive = competition['is_active'] == true;
    final kind = competition['competition_kind']?.toString() ?? 'league';
    final region = competition['region']?.toString() ?? '';
    final country = competition['country_name']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: GlassCard(
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        competition['name']?.toString() ?? '',
                        style: TypographyTokens.titleLarge().copyWith(
                          color: ColorTokens.onSurface,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        competition['short_name']?.toString() ?? '',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(isActive: isActive),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),

            // Info chips
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children: [
                _InfoChip(
                  icon: Icons.category_rounded,
                  label: kind.toUpperCase(),
                ),
                _InfoChip(
                  icon: Icons.public_rounded,
                  label: region.toUpperCase(),
                ),
                if (country != null)
                  _InfoChip(icon: Icons.flag_rounded, label: country),
                if (competition['organizer'] != null)
                  _InfoChip(
                    icon: Icons.business_rounded,
                    label: competition['organizer'].toString(),
                  ),
              ],
            ),
            if (competition['format_notes']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                competition['format_notes'].toString(),
                style: TypographyTokens.bodySmall(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing3),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openSeasonManager(competition),
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('SEASONS'),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                TextButton.icon(
                  onPressed: () => _openCompetitionForm(competition),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('EDIT'),
                ),
                const SizedBox(width: SpacingTokens.spacing2),
                TextButton.icon(
                  onPressed: () => _toggleActive(competition),
                  icon: Icon(
                    isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 16,
                  ),
                  label: Text(isActive ? 'DEACTIVATE' : 'ACTIVATE'),
                  style: TextButton.styleFrom(
                    foregroundColor: isActive
                        ? ColorTokens.error
                        : ColorTokens.success,
                  ),
                ),
              ],
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
              Icons.emoji_events_rounded,
              size: 48,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'No competitions found',
              style: TypographyTokens.headlineMedium().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Add a competition or adjust filters.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: 'Add competition',
              fullWidth: true,
              onTap: () => _openCompetitionForm(),
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
              'Failed to load competitions',
              style: TypographyTokens.headlineMedium().copyWith(
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: 'Retry',
              fullWidth: true,
              onTap: _loadCompetitions,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Competition Form Bottom Sheet ──

