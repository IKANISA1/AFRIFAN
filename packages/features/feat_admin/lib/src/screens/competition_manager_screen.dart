import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            ClaymorphicButton(
              label: 'ADD COMPETITION',
              width: double.infinity,
              onPressed: () => _openCompetitionForm(),
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
            ClaymorphicButton(
              label: 'RETRY',
              width: double.infinity,
              onPressed: _loadCompetitions,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Competition Form Bottom Sheet ──

class _CompetitionFormSheet extends StatefulWidget {
  const _CompetitionFormSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_CompetitionFormSheet> createState() => _CompetitionFormSheetState();
}

class _CompetitionFormSheetState extends State<_CompetitionFormSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _shortNameCtl;
  late final TextEditingController _slugCtl;
  late final TextEditingController _organizerCtl;
  late final TextEditingController _countryCodeCtl;
  late final TextEditingController _countryNameCtl;
  late final TextEditingController _formatNotesCtl;
  late String _kind;
  late String _region;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtl = TextEditingController(text: e?['name']?.toString() ?? '');
    _shortNameCtl = TextEditingController(
      text: e?['short_name']?.toString() ?? '',
    );
    _slugCtl = TextEditingController(text: e?['slug']?.toString() ?? '');
    _organizerCtl = TextEditingController(
      text: e?['organizer']?.toString() ?? '',
    );
    _countryCodeCtl = TextEditingController(
      text: e?['country_code']?.toString() ?? '',
    );
    _countryNameCtl = TextEditingController(
      text: e?['country_name']?.toString() ?? '',
    );
    _formatNotesCtl = TextEditingController(
      text: e?['format_notes']?.toString() ?? '',
    );
    _kind = e?['competition_kind']?.toString() ?? 'league';
    _region = e?['region']?.toString() ?? 'africa';
    _isActive = e?['is_active'] != false;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _shortNameCtl.dispose();
    _slugCtl.dispose();
    _organizerCtl.dispose();
    _countryCodeCtl.dispose();
    _countryNameCtl.dispose();
    _formatNotesCtl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtl.text.trim();
    final shortName = _shortNameCtl.text.trim();
    final slug = _slugCtl.text.trim();
    if (name.isEmpty || shortName.isEmpty || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, short name, and slug required.')),
      );
      return;
    }

    final data = <String, dynamic>{
      'name': name,
      'short_name': shortName,
      'slug': slug,
      'competition_kind': _kind,
      'region': _region,
      'organizer': _organizerCtl.text.trim().isEmpty
          ? null
          : _organizerCtl.text.trim(),
      'country_code': _countryCodeCtl.text.trim().isEmpty
          ? null
          : _countryCodeCtl.text.trim(),
      'country_name': _countryNameCtl.text.trim().isEmpty
          ? null
          : _countryNameCtl.text.trim(),
      'format_notes': _formatNotesCtl.text.trim(),
      'is_active': _isActive,
    };

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: SpacingTokens.spacing6,
        right: SpacingTokens.spacing6,
        top: SpacingTokens.spacing6,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + SpacingTokens.spacing6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
              isEditing ? 'EDIT COMPETITION' : 'ADD COMPETITION',
              style: TypographyTokens.titleLarge().copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: SpacingTokens.spacing5),

            _buildField('Name', _nameCtl),
            _buildField('Short Name', _shortNameCtl),
            _buildField('Slug', _slugCtl, hint: 'e.g. my-new-league'),
            _buildField('Organizer', _organizerCtl, hint: 'Optional'),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    'Country Code',
                    _countryCodeCtl,
                    hint: 'RW',
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: _buildField(
                    'Country Name',
                    _countryNameCtl,
                    hint: 'Rwanda',
                  ),
                ),
              ],
            ),
            _buildField('Format Notes', _formatNotesCtl, hint: 'Optional'),

            const SizedBox(height: SpacingTokens.spacing4),

            // Kind selector
            Text(
              'KIND',
              style: TypographyTokens.labelSmall().copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: ['league', 'cup', 'tournament'].map((k) {
                return ChoiceChip(
                  selected: _kind == k,
                  label: Text(k.toUpperCase()),
                  onSelected: (_) => setState(() => _kind = k),
                );
              }).toList(),
            ),

            const SizedBox(height: SpacingTokens.spacing4),

            // Region selector
            Text(
              'REGION',
              style: TypographyTokens.labelSmall().copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: ['africa', 'europe', 'international', 'global'].map((
                r,
              ) {
                return ChoiceChip(
                  selected: _region == r,
                  label: Text(r.toUpperCase()),
                  onSelected: (_) => setState(() => _region = r),
                );
              }).toList(),
            ),

            const SizedBox(height: SpacingTokens.spacing4),

            // Active toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('ACTIVE', style: TypographyTokens.titleMedium()),
              subtitle: Text(
                _isActive
                    ? 'Visible to fans in the prediction engine'
                    : 'Hidden from the prediction engine',
                style: TypographyTokens.bodySmall(),
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),

            const SizedBox(height: SpacingTokens.spacing5),

            ClaymorphicButton(
              label: isEditing ? 'SAVE CHANGES' : 'CREATE COMPETITION',
              width: double.infinity,
              onPressed: _submit,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: TextField(
        controller: controller,
        style: TypographyTokens.bodyLarge(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: BorderTokens.input(borderRadius: BorderRadius.circular(16)),
          filled: true,
          fillColor: ColorTokens.surfaceContainerHigh,
        ),
      ),
    );
  }
}

// ── Season Manager Bottom Sheet ──

class _SeasonManagerSheet extends StatefulWidget {
  const _SeasonManagerSheet({
    required this.competitionId,
    required this.competitionName,
    required this.supabaseClient,
  });

  final String competitionId;
  final String competitionName;
  final dynamic supabaseClient;

  @override
  State<_SeasonManagerSheet> createState() => _SeasonManagerSheetState();
}

class _SeasonManagerSheetState extends State<_SeasonManagerSheet> {
  List<Map<String, dynamic>> _seasons = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = widget.supabaseClient as SupabaseClient;
      final rows = await client
          .schema('football')
          .from('seasons')
          .select()
          .eq('competition_id', widget.competitionId)
          .order('year_start', ascending: false);

      if (!mounted) return;
      setState(() {
        _seasons = List<Map<String, dynamic>>.from(rows);
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

  Future<void> _addSeason() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SeasonFormDialog(competitionId: widget.competitionId),
    );

    if (result == null) return;

    try {
      final client = widget.supabaseClient as SupabaseClient;
      await client.schema('football').from('seasons').insert(result);
      await _loadSeasons();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Season created'),
          backgroundColor: ColorTokens.success,
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

  Future<void> _toggleSeasonActive(Map<String, dynamic> season) async {
    final id = season['id']?.toString();
    final active = season['is_active'] == true;
    if (id == null) return;

    try {
      final client = widget.supabaseClient as SupabaseClient;
      await client
          .schema('football')
          .from('seasons')
          .update({'is_active': !active})
          .eq('id', id);
      await _loadSeasons();
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEASONS',
                          style: TypographyTokens.titleLarge().copyWith(
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          widget.competitionName,
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _addSeason,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Add season',
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing4),

              // Content
              Expanded(
                child: _isLoading
                    ? const AfriSkeletonList()
                    : _error != null
                    ? Center(
                        child: Text(
                          'Error: $_error',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      )
                    : _seasons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 48,
                              color: ColorTokens.onSurfaceVariant,
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            Text(
                              'No seasons yet',
                              style: TypographyTokens.headlineMedium().copyWith(
                                color: ColorTokens.onSurface,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _seasons.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: SpacingTokens.spacing3),
                        itemBuilder: (ctx, i) => _buildSeasonRow(_seasons[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeasonRow(Map<String, dynamic> season) {
    final isActive = season['is_active'] == true;
    final status = season['status']?.toString() ?? 'planned';

    return GlassCard(
      animate: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season['label']?.toString() ?? '',
                  style: TypographyTokens.titleMedium().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing1),
                Row(
                  children: [
                    _StatusBadge(isActive: isActive),
                    const SizedBox(width: SpacingTokens.spacing2),
                    _InfoChip(
                      icon: Icons.schedule_rounded,
                      label: status.toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _toggleSeasonActive(season),
            icon: Icon(
              isActive
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
            ),
            tooltip: isActive ? 'Deactivate' : 'Activate',
          ),
        ],
      ),
    );
  }
}

// ── Season Form Dialog ──

class _SeasonFormDialog extends StatefulWidget {
  const _SeasonFormDialog({required this.competitionId});

  final String competitionId;

  @override
  State<_SeasonFormDialog> createState() => _SeasonFormDialogState();
}

class _SeasonFormDialogState extends State<_SeasonFormDialog> {
  final _slugCtl = TextEditingController();
  final _labelCtl = TextEditingController();
  final _yearStartCtl = TextEditingController();
  final _yearEndCtl = TextEditingController();
  String _status = 'planned';

  @override
  void dispose() {
    _slugCtl.dispose();
    _labelCtl.dispose();
    _yearStartCtl.dispose();
    _yearEndCtl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_slugCtl.text.trim().isEmpty || _labelCtl.text.trim().isEmpty) {
      return;
    }

    Navigator.of(context).pop(<String, dynamic>{
      'competition_id': widget.competitionId,
      'slug': _slugCtl.text.trim(),
      'label': _labelCtl.text.trim(),
      'year_start': int.tryParse(_yearStartCtl.text.trim()),
      'year_end': int.tryParse(_yearEndCtl.text.trim()),
      'status': _status,
      'is_active': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ColorTokens.surfaceContainerLow,
      title: Text(
        'ADD SEASON',
        style: TypographyTokens.titleLarge().copyWith(letterSpacing: 1.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _slugCtl,
              decoration: const InputDecoration(
                labelText: 'Slug',
                hintText: 'e.g. my-league-2026',
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: _labelCtl,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. 2025/2026',
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yearStartCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year Start'),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: TextField(
                    controller: _yearEndCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year End'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: ['planned', 'active', 'finished', 'archived'].map((s) {
                return ChoiceChip(
                  selected: _status == s,
                  label: Text(s.toUpperCase()),
                  onSelected: (_) => setState(() => _status = s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _submit, child: const Text('CREATE')),
      ],
    );
  }
}

// ── Shared Widgets ──

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? ColorTokens.success : ColorTokens.error;
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
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TypographyTokens.labelSmall().copyWith(color: color),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing2,
        vertical: SpacingTokens.spacing1,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorTokens.onSurfaceVariant),
          const SizedBox(width: SpacingTokens.spacing1),
          Text(label, style: TypographyTokens.labelSmall()),
        ],
      ),
    );
  }
}
