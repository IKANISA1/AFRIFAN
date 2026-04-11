import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _targetController = TextEditingController();
  final _recipientController = TextEditingController();

  GroupPrivacy _privacy = GroupPrivacy.private_;
  ContributionGroupType _groupType = ContributionGroupType.fanCircle;
  DateTime? _deadline;
  bool _isRecurring = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _recipientController.text = user?.momoNumber ?? user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _targetController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  int get _targetAmount {
    final digits = _targetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _createGroup() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/onboarding');
      return;
    }

    if (!user.hasMomo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link your MOMO number before creating a circle.'),
        ),
      );
      context.push('/profile_setup');
      return;
    }

    if (_nameController.text.trim().isEmpty || _targetAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a circle name and a valid target amount.'),
        ),
      );
      return;
    }

    if (_recipientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A MOMO recipient is required for collections.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(clubRepositoryProvider);
      final group = ContributionGroup(
        id: '',
        creatorId: user.id,
        name: _nameController.text.trim(),
        description: _purposeController.text.trim().isEmpty
            ? null
            : _purposeController.text.trim(),
        groupType: _groupType,
        privacy: _privacy,
        targetAmount: _targetAmount,
        paymentRecipient: _recipientController.text.trim(),
        paymentRecipientType: PaymentRecipientType.phoneNumber,
        deadline: _deadline,
        isRecurring: _isRecurring,
        createdAt: DateTime.now(),
      );

      final created = await repo.createContributionGroup(group);
      await repo.recordXpEvent(
        userId: user.id,
        eventType: XpEventType.createGroup,
        metadata: <String, Object?>{'group_id': created.id},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circle created successfully.'),
          backgroundColor: ColorTokens.success,
        ),
      );
      context.go('/contribute/group/${created.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create circle: $error'),
          backgroundColor: ColorTokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final previewName = _nameController.text.trim().isEmpty
        ? 'YOUR CIRCLE'
        : _nameController.text.trim().toUpperCase();
    final previewTarget = _targetAmount > 0
        ? currency.format(_targetAmount)
        : currency.format(0);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'NEW CIRCLE',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          children: [
            _ContributionInput(
              label: 'GROUP NAME',
              controller: _nameController,
              hint: 'APR Final Away Convoy',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _ContributionInput(
              label: 'PURPOSE',
              controller: _purposeController,
              hint: 'Transport, tickets, and tifo',
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _ContributionInput(
              label: 'TARGET AMOUNT',
              controller: _targetController,
              hint: '${context.afriCurrencySymbol} 500,000',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _ContributionInput(
              label: 'COLLECTION MOMO',
              controller: _recipientController,
              hint: '+250 7XX XXX XXX',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GROUP TYPE', style: TypographyTokens.labelSmall()),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: ContributionGroupType.values.map((type) {
                      return ChoiceChip(
                        selected: _groupType == type,
                        label: Text(type.label),
                        onSelected: (_) => setState(() => _groupType = type),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRIVACY', style: TypographyTokens.labelSmall()),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    children: GroupPrivacy.values.map((privacy) {
                      return ChoiceChip(
                        selected: _privacy == privacy,
                        label: Text(privacy.value.toUpperCase()),
                        onSelected: (_) => setState(() => _privacy = privacy),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              onTap: _pickDeadline,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEADLINE', style: TypographyTokens.labelSmall()),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          _deadline == null
                              ? 'Choose a closing date'
                              : AfriDateFormatter.formatDate(_deadline!),
                          style: TypographyTokens.bodyLarge(),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.calendar_month_rounded),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            SwitchListTile.adaptive(
              value: _isRecurring,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing2,
              ),
              title: Text(
                'Recurring circle',
                style: TypographyTokens.bodyLarge(),
              ),
              subtitle: Text(
                'Keep the group open for repeated collections.',
                style: TypographyTokens.bodySmall(),
              ),
              onChanged: (value) => setState(() => _isRecurring = value),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE PREVIEW',
                    style: TypographyTokens.monolithFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(previewName, style: TypographyTokens.bodyLarge()),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    '${_privacy.value.toUpperCase()}  •  ${_groupType.label}',
                    style: TypographyTokens.bodySmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    'Target: $previewTarget',
                    style: TypographyTokens.bodySmall(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            ClaymorphicButton(
              label: _submitting ? 'CREATING' : 'CREATE CIRCLE',
              width: double.infinity,
              onPressed: _submitting ? null : _createGroup,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionInput extends StatelessWidget {
  const _ContributionInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
