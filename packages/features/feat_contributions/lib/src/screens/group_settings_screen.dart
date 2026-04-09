import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/contribution_overlays.dart';
import '../widgets/group_settings_widgets.dart';

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

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  final _nameController = TextEditingController();
  final _momoController = TextEditingController();
  final _targetController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _privacy = 'private';
  DateTime? _deadline;
  String? _inviteCode;
  String _groupName = 'CIRCLE';
  bool _allowChat = true;
  bool _isLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _momoController.dispose();
    _targetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final group = await client
          .from('contribution_groups')
          .select()
          .eq('id', widget.groupId)
          .eq('club_id', clubId)
          .maybeSingle();

      if (!mounted) return;
      if (group == null) {
        setState(() => _isLoading = false);
        return;
      }

      final deadlineRaw = group['deadline']?.toString();
      _deadline = deadlineRaw == null || deadlineRaw.isEmpty
          ? null
          : DateTime.tryParse(deadlineRaw);
      _groupName = group['name']?.toString().toUpperCase() ?? 'CIRCLE';
      _nameController.text = group['name']?.toString() ?? '';
      _momoController.text =
          group['receiving_momo_code']?.toString() ??
          group['momo_recipient_code']?.toString() ??
          '';
      _targetController.text = ((group['target_amount'] as num?)?.toInt() ?? 0)
          .toString();
      _descriptionController.text = group['description']?.toString() ?? '';
      _privacy = group['privacy']?.toString().toLowerCase() ?? 'private';
      _inviteCode = group['invite_code']?.toString();
      _allowChat = group['allow_chat'] as bool? ?? true;

      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        throw StateError('Could not resolve the active club.');
      }
      await client
          .from('contribution_groups')
          .update({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'privacy': _privacy,
            'target_amount': int.tryParse(_targetController.text.trim()) ?? 0,
            'deadline': _deadline?.toIso8601String(),
            'receiving_momo_code': _momoController.text.trim(),
            'allow_chat': _allowChat,
          })
          .eq('id', widget.groupId)
          .eq('club_id', clubId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circle settings updated.'),
          backgroundColor: ColorTokens.success,
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save changes: $error'),
          backgroundColor: ColorTokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) return;
    setState(() => _deadline = picked);
  }

  Future<void> _closeCircle() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        throw StateError('Could not resolve the active club.');
      }
      await client
          .from('contribution_groups')
          .update({'is_closed': true})
          .eq('id', widget.groupId)
          .eq('club_id', clubId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circle closed.'),
          backgroundColor: ColorTokens.success,
        ),
      );
      context.go('/contribute/groups');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not close this circle: $error'),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  Future<void> _deleteCircle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: ColorTokens.scrim,
      builder: (context) => AlertDialog(
        backgroundColor: ColorTokens.surfaceContainerHigh,
        title: const Text('Delete circle?'),
        content: const Text('This removes the circle permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: ColorTokens.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        throw StateError('Could not resolve the active club.');
      }
      await client
          .from('contribution_groups')
          .delete()
          .eq('id', widget.groupId)
          .eq('club_id', clubId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circle deleted.'),
          backgroundColor: ColorTokens.success,
        ),
      );
      context.go('/contribute/groups');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete this circle: $error'),
          backgroundColor: ColorTokens.error,
        ),
      );
    }
  }

  String get _privacyLabel {
    switch (_privacy) {
      case 'public':
        return 'PUBLIC';
      case 'members':
        return 'FRIENDS OF MEMBERS';
      default:
        return 'PRIVATE';
    }
  }

  void _setPrivacyFromLabel(String label) {
    switch (label) {
      case 'PUBLIC':
        _privacy = 'public';
      case 'FRIENDS OF MEMBERS':
        _privacy = 'members';
      default:
        _privacy = 'private';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'CIRCLE SETTINGS',
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: Column(
                children: [
                  GlassCard(
                    animate: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _groupName,
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: ColorTokens.onSurface,
                                ),
                              ),
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                'Privacy, collection & export controls.',
                                style: TypographyTokens.bodyMedium(),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing3,
                            vertical: SpacingTokens.spacing2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _privacyLabel,
                            style: TypographyTokens.labelSmall().copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  ContributionInput(
                    label: 'GROUP NAME',
                    controller: _nameController,
                    hint: 'APR Final Away Convoy',
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRIVACY LEVEL',
                          style: TypographyTokens.labelSmall(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          runSpacing: SpacingTokens.spacing2,
                          children: ['PUBLIC', 'FRIENDS OF MEMBERS', 'PRIVATE']
                              .map(
                                (label) => PrivacyPill(
                                  label: label,
                                  selected: _privacyLabel == label,
                                  onTap: () => setState(
                                    () => _setPrivacyFromLabel(label),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        TextButton(
                          onPressed: () async {
                            final next = await showGroupPrivacySettingsSheet(
                              context,
                              currentValue: _privacyLabel,
                            );
                            if (!mounted || next == null) return;
                            setState(() => _setPrivacyFromLabel(next));
                          },
                          child: const Text('OPEN PRIVACY GUIDE'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ContributionInput(
                    label: 'TARGET AMOUNT',
                    controller: _targetController,
                    hint: '500000',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEADLINE', style: TypographyTokens.labelSmall()),
                        const SizedBox(height: SpacingTokens.spacing2),
                        InkWell(
                          onTap: _pickDeadline,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SpacingTokens.spacing4,
                              vertical: SpacingTokens.spacing4,
                            ),
                            decoration: BoxDecoration(
                              color: ColorTokens.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _deadline == null
                                        ? 'Select a collection deadline'
                                        : AfriDateFormatter.formatDate(
                                            _deadline!,
                                          ),
                                    style: TypographyTokens.bodyLarge(),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ContributionInput(
                    label: 'MOMO NUMBER',
                    controller: _momoController,
                    hint: '+250 7XX XXX XXX',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ContributionInput(
                    label: 'DESCRIPTION',
                    controller: _descriptionController,
                    hint: 'Circle purpose and logistics',
                    maxLines: 2,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _allowChat,
                          activeThumbColor: ColorTokens.clubPrimary,
                          onChanged: (value) =>
                              setState(() => _allowChat = value),
                          title: const Text('Allow chat'),
                          subtitle: const Text(
                            'Let circle members coordinate in-app.',
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text('TOOLS', style: TypographyTokens.labelSmall()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Download statement'),
                          subtitle: const Text('PDF or CSV export'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          onTap: () => context.push(
                            '/contribute/group/${widget.groupId}/statement',
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Invite members'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          onTap: () => showGroupInviteCodeSheet(
                            context,
                            inviteCode: _inviteCode,
                            groupName: _groupName,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  GlassCard(
                    animate: false,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ColorTokens.error.withValues(alpha: 0.32),
                        ),
                      ),
                      padding: const EdgeInsets.all(SpacingTokens.spacing5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DANGER ZONE',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ColorTokens.error,
                            ),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            'Close when done, or delete if created by mistake.',
                            style: TypographyTokens.bodyMedium(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          OutlinedButton(
                            onPressed: _closeCircle,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              foregroundColor: ColorTokens.warning,
                            ),
                            child: const Text('CLOSE CIRCLE'),
                          ),
                          const SizedBox(height: SpacingTokens.spacing2),
                          TextButton(
                            onPressed: _deleteCircle,
                            child: const Text(
                              'DELETE CIRCLE',
                              style: TextStyle(color: ColorTokens.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  ClaymorphicButton(
                    label: _saving ? 'SAVING' : 'SAVE CHANGES',
                    width: double.infinity,
                    onPressed: _saving ? null : _saveChanges,
                  ),
                ],
              ),
            ),
    );
  }
}
