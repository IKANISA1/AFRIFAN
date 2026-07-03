part of '../../screens/competition_manager_screen.dart';

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
      AfriToast.error(context, 'Name, short name, and slug required.');
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

    context.pop(data);
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
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusSm / 4),
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
                return AfriChoiceChip(
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
                return AfriChoiceChip(
                  selected: _region == r,
                  label: Text(r.toUpperCase()),
                  onSelected: (_) => setState(() => _region = r),
                );
              }).toList(),
            ),

            const SizedBox(height: SpacingTokens.spacing4),

            // Active toggle
            AfriSwitchListTile(
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

            AfriButton(
              label: isEditing ? 'Save changes' : 'Create competition',
              fullWidth: true,
              onTap: _submit,
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
      child: AfriInputField(controller: controller, label: label, hint: hint),
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
    unawaited(_loadSeasons());
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
      AfriToast.success(context, 'Season created');
    } catch (e) {
      if (!mounted) return;
      AfriToast.error(context, 'Failed: $e');
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
      AfriToast.error(context, 'Failed: $e');
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
                    borderRadius: BorderRadius.circular(
                      ShapeTokens.radiusSm / 4,
                    ),
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
                  AfriIconButton(
                    icon: AfriIcons.add,
                    onTap: _addSeason,
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
                    ? const SizedBox.shrink()
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
                      icon: AfriIcons.statusPending,
                      label: status.toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AfriIconButton(
            icon: isActive ? AfriIcons.visibilityOff : AfriIcons.visibility,
            onTap: () => _toggleSeasonActive(season),
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

    context.pop(<String, dynamic>{
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
    return AfriAlertDialog(
      title: Text(
        'ADD SEASON',
        style: TypographyTokens.titleLarge().copyWith(letterSpacing: 1.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriInputField(
              controller: _slugCtl,
              label: 'Slug',
              hint: 'e.g. my-league-2026',
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriInputField(
              controller: _labelCtl,
              label: 'Label',
              hint: 'e.g. 2025/2026',
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                Expanded(
                  child: AfriInputField(
                    controller: _yearStartCtl,
                    keyboardType: TextInputType.number,
                    label: 'Year Start',
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: AfriInputField(
                    controller: _yearEndCtl,
                    keyboardType: TextInputType.number,
                    label: 'Year End',
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: ['planned', 'active', 'finished', 'archived'].map((s) {
                return AfriChoiceChip(
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
        AfriTextButton(
          onPressed: () => context.pop(),
          child: const Text('CANCEL'),
        ),
        AfriTextButton(onPressed: _submit, child: const Text('CREATE')),
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
        borderRadius: ShapeTokens.buttonRadius,
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
        borderRadius: ShapeTokens.cardRadius,
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
