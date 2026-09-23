import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_matches_controller.dart';

typedef MatchSaveCallback =
    Future<bool> Function(Map<String, dynamic> values, {String? matchId});

/// Shows match creation/editing form as a modal bottom sheet.
///
/// Returns `true` if the match was saved successfully, `null` otherwise.
Future<bool?> showMatchComposerSheet(
  BuildContext context, {
  required MatchSaveCallback onSave,
  AdminMatchItem? existing,
  String? partnerId,
}) {
  return showAfriBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MatchComposerSheet(
      onSave: onSave,
      existing: existing,
      partnerId: partnerId,
    ),
  );
}

class _MatchComposerSheet extends StatefulWidget {
  const _MatchComposerSheet({
    required this.onSave,
    this.existing,
    this.partnerId,
  });

  final MatchSaveCallback onSave;
  final AdminMatchItem? existing;
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
  late final TextEditingController _summaryController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isOnSale;
  String? _errorText;
  bool _saving = false;

  AdminMatchItem? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _homeController = TextEditingController(
      text: _existing?.homeTeam ?? RuntimeBranding.displayHomeTeamName,
    );
    _awayController = TextEditingController(text: _existing?.awayTeam ?? '');
    _competitionController = TextEditingController(
      text: _existing?.competition ?? RuntimeBranding.displayCompetitionName,
    );
    _venueController = TextEditingController(
      text: _existing?.venue ?? RuntimeBranding.displayHomeVenueName,
    );
    _generalController = TextEditingController(
      text: '${_existing?.generalPrice ?? 3000}',
    );
    _vipController = TextEditingController(
      text: '${_existing?.vipPrice ?? 30000}',
    );
    _capacityController = TextEditingController(
      text: '${_existing?.capacity ?? 18000}',
    );
    _summaryController = TextEditingController(text: _existing?.summary ?? '');

    _selectedDate =
        _existing?.matchDate ?? DateTime.now().add(const Duration(days: 7));
    _selectedTime =
        _parseTime(_existing?.kickoffTime) ??
        const TimeOfDay(hour: 15, minute: 30);
    _isOnSale = _existing?.isOnSale ?? false;
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
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final payload = <String, dynamic>{
        'partner_id': _existing?.partnerId ?? widget.partnerId,
        'home_team': _homeController.text.trim(),
        'away_team': _awayController.text.trim(),
        'competition': _competitionController.text.trim(),
        'venue': _venueController.text.trim(),
        'match_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'kickoff_time':
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
        'is_on_sale': _isOnSale,
        'ticket_general_price': int.tryParse(_generalController.text.trim()),
        'ticket_vip_price': int.tryParse(_vipController.text.trim()),
        'capacity': int.tryParse(_capacityController.text.trim()),
        'match_status': _existing?.status ?? 'scheduled',
        'home_score': _existing?.homeScore ?? 0,
        'away_score': _existing?.awayScore ?? 0,
        'live_minute': _existing?.liveMinute ?? 0,
        'match_summary': _summaryController.text.trim(),
      };

      final saved = await widget.onSave(payload, matchId: _existing?.id);
      if (!mounted) return;
      if (saved) {
        context.pop(true);
        return;
      }
      setState(() {
        _saving = false;
        _errorText = context.afriL10n.adminMatchSaveNotConfirmed;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = context.afriL10n.adminMatchReviewFields;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = context.afriL10n.adminMatchSaveFailedRefresh;
      });
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
    final currencySymbol = context.afriCurrencySymbol;
    return Container(
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: BorderTokens.ghost(),
      ),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        SpacingTokens.spacing5,
        SpacingTokens.spacing6,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            SpacingTokens.spacing5,
      ),
      child: IgnorePointer(
        ignoring: _saving,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _existing == null
                    ? context.afriL10n.adminMatchCreateTitle
                    : context.afriL10n.adminMatchUpdateTitle,
                style: TypographyTokens.headlineMedium().copyWith(
                  color: ColorTokens.onSurface,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Row(
                children: [
                  Expanded(
                    child: AfriTeamField(
                      value: _homeController.text,
                      semanticLabel: context.afriL10n.adminMatchHomeTeam,
                      onChanged: (value) =>
                          setState(() => _homeController.text = value),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriTeamField(
                      value: _awayController.text,
                      semanticLabel: context.afriL10n.adminMatchAwayTeam,
                      onChanged: (value) =>
                          setState(() => _awayController.text = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: _competitionController,
                label: context.afriL10n.adminMatchCompetition,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: _venueController,
                label: context.afriL10n.adminMatchVenue,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Row(
                children: [
                  Expanded(
                    child: AfriOutlinedButton(
                      onPressed: _pickDate,
                      child: Text(
                        DateFormat(
                          'dd MMM yyyy',
                          context.afriL10n.localeName,
                        ).format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriOutlinedButton(
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
                    child: AfriInputField(
                      controller: _generalController,
                      keyboardType: TextInputType.number,
                      label: context.afriL10n.adminMatchGeneralPrice(
                        currencySymbol,
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriInputField(
                      controller: _vipController,
                      keyboardType: TextInputType.number,
                      label: context.afriL10n.adminMatchVipPrice(
                        currencySymbol,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                label: context.afriL10n.adminMatchCapacity,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriSwitchListTile(
                value: _isOnSale,
                contentPadding: EdgeInsets.zero,
                title: Text(context.afriL10n.adminMatchTicketsOnSale),
                onChanged: (value) => setState(() => _isOnSale = value),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                context.afriL10n.adminMatchAutomaticResults,
                style: TypographyTokens.bodyMedium(
                  ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: _summaryController,
                minLines: 2,
                maxLines: 4,
                label: context.afriL10n.adminMatchSummary,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  _errorText!,
                  style: TypographyTokens.bodySmall().copyWith(
                    color: ColorTokens.error,
                  ),
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing4),
              AfriButton(
                label: _existing == null
                    ? context.afriL10n.adminMatchSave
                    : context.afriL10n.adminMatchUpdate,
                fullWidth: true,
                isLoading: _saving,
                onTap: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
