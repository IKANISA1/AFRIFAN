part of '../../screens/competition_manager_screen.dart';

class _CompetitionFormSheet extends StatefulWidget {
  const _CompetitionFormSheet({this.existing});

  final AdminCompetitionItem? existing;

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
    final existing = widget.existing;
    _nameCtl = TextEditingController(text: existing?.name ?? '');
    _shortNameCtl = TextEditingController(text: existing?.shortName ?? '');
    _slugCtl = TextEditingController(text: existing?.slug ?? '');
    _organizerCtl = TextEditingController(text: existing?.organizer ?? '');
    _countryCodeCtl = TextEditingController(text: existing?.countryCode ?? '');
    _countryNameCtl = TextEditingController(text: existing?.countryName ?? '');
    _formatNotesCtl = TextEditingController(text: existing?.formatNotes ?? '');
    _kind = existing?.kind ?? 'league';
    _region = existing?.region ?? 'africa';
    _isActive = existing?.isActive ?? true;
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
    final slug = _slugCtl.text.trim().toLowerCase();
    final countryCode = _countryCodeCtl.text.trim().toUpperCase();
    final organizer = _organizerCtl.text.trim();
    final countryName = _countryNameCtl.text.trim();
    final formatNotes = _formatNotesCtl.text.trim();
    if (name.isEmpty ||
        name.length > 120 ||
        shortName.isEmpty ||
        shortName.length > 32 ||
        !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug) ||
        (countryCode.isNotEmpty &&
            !RegExp(r'^[A-Z]{2,3}$').hasMatch(countryCode)) ||
        organizer.length > 100 ||
        countryName.length > 80 ||
        formatNotes.length > 240) {
      AfriToast.error(
        context,
        'Check the required names, slug, and country code.',
      );
      return;
    }
    context.pop(<String, dynamic>{
      'name': name,
      'short_name': shortName,
      'slug': slug,
      'competition_kind': _kind,
      'region': _region,
      'organizer': _nullable(organizer),
      'country_code': countryCode.isEmpty ? null : countryCode,
      'country_name': _nullable(countryName),
      'format_notes': _nullable(formatNotes),
      'is_active': _isActive,
    });
  }

  String? _nullable(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: SpacingTokens.spacing6,
          right: SpacingTokens.spacing6,
          top: SpacingTokens.spacing6,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom + SpacingTokens.spacing6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: SpacingTokens.spacing5),
              Text(
                editing ? 'EDIT COMPETITION' : 'ADD COMPETITION',
                style: TypographyTokens.titleLarge().copyWith(
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              _field('Name', _nameCtl),
              _field('Short Name', _shortNameCtl),
              _field('Slug', _slugCtl, hint: 'e.g. national-league'),
              _field('Organizer', _organizerCtl, hint: 'Optional'),
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(1) >= 1.8;
                  final fields = <Widget>[
                    _field('Country Code', _countryCodeCtl, hint: 'RW'),
                    _field('Country Name', _countryNameCtl, hint: 'Rwanda'),
                  ];
                  if (largeText || constraints.maxWidth < 320) {
                    return Column(children: fields);
                  }
                  return Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(child: fields[1]),
                    ],
                  );
                },
              ),
              _field('Format Notes', _formatNotesCtl, hint: 'Optional'),
              const SizedBox(height: SpacingTokens.spacing3),
              _selector(
                label: 'KIND',
                values: const <String>['league', 'cup', 'tournament'],
                selected: _kind,
                onSelected: (value) => setState(() => _kind = value),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              _selector(
                label: 'REGION',
                values: const <String>[
                  'africa',
                  'europe',
                  'international',
                  'global',
                ],
                selected: _region,
                onSelected: (value) => setState(() => _region = value),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('ACTIVE', style: TypographyTokens.titleMedium()),
                subtitle: Text(
                  _isActive
                      ? 'Available to configured prediction journeys'
                      : 'Unavailable to prediction journeys',
                  style: TypographyTokens.bodySmall(),
                ),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                label: editing ? 'Save changes' : 'Create competition',
                fullWidth: true,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: AfriInputField(controller: controller, label: label, hint: hint),
    );
  }

  Widget _selector({
    required String label,
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TypographyTokens.labelSmall()),
        const SizedBox(height: SpacingTokens.spacing2),
        Wrap(
          spacing: SpacingTokens.spacing2,
          runSpacing: SpacingTokens.spacing2,
          children: values
              .map(
                (value) => AfriChoiceChip(
                  selected: selected == value,
                  label: Text(value.toUpperCase()),
                  onSelected: (_) => onSelected(value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SeasonManagerSheet extends ConsumerWidget {
  const _SeasonManagerSheet({required this.competition});

  final AdminCompetitionItem competition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminCompetitionsProvider);
    final snapshot = value.valueOrNull;
    final seasons =
        snapshot?.seasons
            .where((season) => season.competitionId == competition.id)
            .toList(growable: false) ??
        const <AdminCompetitionSeason>[];
    final enabled = snapshot?.actionsEnabled == true && !value.isLoading;
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.46,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: SpacingTokens.spacing5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            competition.name,
                            style: TypographyTokens.bodyMedium(),
                          ),
                        ],
                      ),
                    ),
                    AfriIconButton(
                      icon: AfriIcons.add,
                      onTap: enabled ? () => _addSeason(context, ref) : null,
                      tooltip: enabled
                          ? 'Add season'
                          : 'Season actions unavailable',
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Expanded(
                  child: value.isLoading && snapshot == null
                      ? const AfriSkeletonList()
                      : seasons.isEmpty
                      ? AfriStateView.empty(
                          title: 'No seasons configured',
                          message:
                              'Add the first controlled season when access is available.',
                          compact: true,
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: seasons.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: SpacingTokens.spacing3),
                          itemBuilder: (_, index) => _SeasonRow(
                            season: seasons[index],
                            enabled: enabled,
                            onToggle: () => _confirmSeasonToggle(
                              context,
                              ref,
                              seasons[index],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addSeason(BuildContext context, WidgetRef ref) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SeasonFormDialog(competitionId: competition.id),
    );
    if (payload == null || !context.mounted) return;
    final saved = await ref
        .read(adminCompetitionsProvider.notifier)
        .createSeason(payload);
    if (context.mounted && saved) AfriToast.success(context, 'Season created');
  }

  Future<void> _confirmSeasonToggle(
    BuildContext context,
    WidgetRef ref,
    AdminCompetitionSeason season,
  ) async {
    final activating = !season.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AfriAlertDialog(
        title: Text(activating ? 'ACTIVATE SEASON?' : 'DEACTIVATE SEASON?'),
        content: Text(
          '${season.label} will be ${activating ? 'available' : 'unavailable'} to configured competition journeys.',
        ),
        actions: [
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          AfriTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(activating ? 'ACTIVATE' : 'DEACTIVATE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final saved = await ref
        .read(adminCompetitionsProvider.notifier)
        .setSeasonActive(season.id, activating);
    if (context.mounted && saved) {
      AfriToast.success(
        context,
        activating ? 'Season activated' : 'Season deactivated',
      );
    }
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({
    required this.season,
    required this.enabled,
    required this.onToggle,
  });

  final AdminCompetitionSeason season;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season.label,
                  style: TypographyTokens.titleMedium().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: [
                    _StatusBadge(isActive: season.isActive),
                    _InfoChip(
                      icon: AfriIcons.statusPending,
                      label: season.status.toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          AfriIconButton(
            icon: season.isActive
                ? AfriIcons.visibilityOff
                : AfriIcons.visibility,
            onTap: enabled ? onToggle : null,
            tooltip: season.isActive ? 'Deactivate season' : 'Activate season',
          ),
        ],
      ),
    );
  }
}

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
    final slug = _slugCtl.text.trim().toLowerCase();
    final label = _labelCtl.text.trim();
    final start = int.tryParse(_yearStartCtl.text.trim());
    final end = int.tryParse(_yearEndCtl.text.trim());
    final yearsValid =
        (start == null || (start >= 1900 && start <= 2200)) &&
        (end == null || (end >= 1900 && end <= 2200)) &&
        (start == null || end == null || end >= start);
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug) ||
        label.isEmpty ||
        label.length > 64 ||
        !yearsValid) {
      AfriToast.error(context, 'Check the season slug, label, and years.');
      return;
    }
    context.pop(<String, dynamic>{
      'competition_id': widget.competitionId,
      'slug': slug,
      'label': label,
      'year_start': start,
      'year_end': end,
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
              hint: 'e.g. league-2026',
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriInputField(
              controller: _labelCtl,
              label: 'Label',
              hint: 'e.g. 2025/2026',
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) >= 1.8;
                final fields = <Widget>[
                  AfriInputField(
                    controller: _yearStartCtl,
                    keyboardType: TextInputType.number,
                    label: 'Year Start',
                  ),
                  AfriInputField(
                    controller: _yearEndCtl,
                    keyboardType: TextInputType.number,
                    label: 'Year End',
                  ),
                ];
                if (largeText || constraints.maxWidth < 320) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: SpacingTokens.spacing3),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              children:
                  const <String>['planned', 'active', 'finished', 'archived']
                      .map(
                        (status) => AfriChoiceChip(
                          selected: _status == status,
                          label: Text(status.toUpperCase()),
                          onSelected: (_) => setState(() => _status = status),
                        ),
                      )
                      .toList(growable: false),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ShapeTokens.radiusSm / 4),
        ),
      ),
    );
  }
}

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
          Flexible(child: Text(label, style: TypographyTokens.labelSmall())),
        ],
      ),
    );
  }
}
