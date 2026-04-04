import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Shows match creation/editing form as a modal bottom sheet.
///
/// Returns `true` if the match was saved successfully, `null` otherwise.
Future<bool?> showMatchComposerSheet(
  BuildContext context, {
  required WidgetRef ref,
  Map<String, dynamic>? existing,
  String? partnerId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MatchComposerSheet(
      ref: ref,
      existing: existing,
      partnerId: partnerId,
    ),
  );
}

class _MatchComposerSheet extends StatefulWidget {
  const _MatchComposerSheet({
    required this.ref,
    this.existing,
    this.partnerId,
  });

  final WidgetRef ref;
  final Map<String, dynamic>? existing;
  final String? partnerId;

  @override
  State<_MatchComposerSheet> createState() => _MatchComposerSheetState();
}

class _MatchComposerSheetState extends State<_MatchComposerSheet> {
  late final TextEditingController _homeController;
  late final TextEditingController _awayController;
  late final TextEditingController _competitionController;
  late final TextEditingController _venueController;
  late final TextEditingController _generalController;
  late final TextEditingController _vipController;
  late final TextEditingController _capacityController;
  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;
  late final TextEditingController _liveMinuteController;
  late final TextEditingController _summaryController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isOnSale;
  late String _matchStatus;
  String? _errorText;

  Map<String, dynamic>? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _homeController = TextEditingController(
      text: _existing?['home_team']?.toString() ??
          RuntimeBranding.displayHomeTeamName,
    );
    _awayController = TextEditingController(
      text: _existing?['away_team']?.toString() ?? '',
    );
    _competitionController = TextEditingController(
      text: _existing?['competition']?.toString() ??
          RuntimeBranding.displayCompetitionName,
    );
    _venueController = TextEditingController(
      text: _existing?['venue']?.toString() ??
          RuntimeBranding.displayHomeVenueName,
    );
    _generalController = TextEditingController(
      text:
          '${(_existing?['ticket_general_price'] as num?)?.toInt() ?? 18000}',
    );
    _vipController = TextEditingController(
      text: '${(_existing?['ticket_vip_price'] as num?)?.toInt() ?? 45000}',
    );
    _capacityController = TextEditingController(
      text: '${(_existing?['capacity'] as num?)?.toInt() ?? 18000}',
    );
    _homeScoreController = TextEditingController(
      text: '${(_existing?['home_score'] as num?)?.toInt() ?? 0}',
    );
    _awayScoreController = TextEditingController(
      text: '${(_existing?['away_score'] as num?)?.toInt() ?? 0}',
    );
    _liveMinuteController = TextEditingController(
      text: '${(_existing?['live_minute'] as num?)?.toInt() ?? 0}',
    );
    _summaryController = TextEditingController(
      text: _existing?['match_summary']?.toString() ?? '',
    );

    _selectedDate =
        DateTime.tryParse(_existing?['match_date']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 7));
    _selectedTime =
        _parseTime(_existing?['kickoff_time']?.toString()) ??
            const TimeOfDay(hour: 15, minute: 30);
    _isOnSale = _existing?['is_on_sale'] == true;
    _matchStatus =
        _existing?['match_status']?.toString().trim().toLowerCase() ??
            'scheduled';
  }

  @override
  void dispose() {
    _homeController.dispose();
    _awayController.dispose();
    _competitionController.dispose();
    _venueController.dispose();
    _generalController.dispose();
    _vipController.dispose();
    _capacityController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _liveMinuteController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    final awayTeam = _awayController.text.trim();
    if (awayTeam.isEmpty) {
      setState(() => _errorText = 'Add the away team first.');
      return;
    }

    try {
      final payload = <String, dynamic>{
        'partner_id': _existing?['partner_id'] ?? widget.partnerId,
        'home_team': _homeController.text.trim(),
        'away_team': awayTeam,
        'competition': _competitionController.text.trim(),
        'venue': _venueController.text.trim(),
        'match_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'kickoff_time':
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
        'is_on_sale': _isOnSale,
        'ticket_general_price':
            int.tryParse(_generalController.text.trim()) ?? 0,
        'ticket_vip_price': int.tryParse(_vipController.text.trim()) ?? 0,
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
        'match_status': _matchStatus,
        'home_score': int.tryParse(_homeScoreController.text.trim()) ?? 0,
        'away_score': int.tryParse(_awayScoreController.text.trim()) ?? 0,
        'live_minute': int.tryParse(_liveMinuteController.text.trim()) ?? 0,
        'match_summary': _summaryController.text.trim(),
      };

      final client = widget.ref.read(supabaseClientProvider);

      if (_existing == null) {
        await client.from('matches').insert(payload);
      } else {
        await client
            .from('matches')
            .update(payload)
            .eq('id', _existing!['id']);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: ColorTokens.ghostBorder, width: 0.5),
      ),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        SpacingTokens.spacing5,
        SpacingTokens.spacing6,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            SpacingTokens.spacing5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _existing == null ? 'CREATE MATCH' : 'UPDATE MATCH',
              style: TypographyTokens.headlineMedium()
                  .copyWith(color: ColorTokens.onSurface),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            TextField(
              controller: _homeController,
              decoration: const InputDecoration(labelText: 'Home Team'),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: _awayController,
              decoration: const InputDecoration(labelText: 'Away Team'),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: _competitionController,
              decoration: const InputDecoration(labelText: 'Competition'),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: _venueController,
              decoration: const InputDecoration(labelText: 'Venue'),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _generalController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'General FRw'),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: TextField(
                    controller: _vipController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'VIP FRw'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            SwitchListTile.adaptive(
              value: _isOnSale,
              contentPadding: EdgeInsets.zero,
              title: const Text('Tickets on sale'),
              onChanged: (value) => setState(() => _isOnSale = value),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            DropdownButtonFormField<String>(
              initialValue: _matchStatus,
              decoration:
                  const InputDecoration(labelText: 'Match status'),
              items: const [
                DropdownMenuItem(
                    value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'live', child: Text('Live')),
                DropdownMenuItem(
                    value: 'halftime', child: Text('Half-time')),
                DropdownMenuItem(
                    value: 'fulltime', child: Text('Full-time')),
                DropdownMenuItem(
                    value: 'postponed', child: Text('Postponed')),
                DropdownMenuItem(
                    value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _matchStatus = value);
              },
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _homeScoreController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Home score'),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: TextField(
                    controller: _awayScoreController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Away score'),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: TextField(
                    controller: _liveMinuteController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Live minute'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            TextField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Match summary / live note',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                _errorText!,
                style: TypographyTokens.bodySmall()
                    .copyWith(color: ColorTokens.error),
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing4),
            ClaymorphicButton(
              label: _existing == null ? 'SAVE MATCH' : 'UPDATE MATCH',
              width: double.infinity,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
