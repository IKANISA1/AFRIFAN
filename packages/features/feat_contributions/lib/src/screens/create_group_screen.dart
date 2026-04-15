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
  PaymentRecipientType _recipientType = PaymentRecipientType.phoneNumber;
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

  AfriCountry? get _collectionCountry {
    final countries = AfriCountryCatalog.all;
    if (countries.isEmpty) {
      return null;
    }

    return AfriCountryCatalog.byIsoCode(RuntimeBranding.displayCountryCode) ??
        countries.first;
  }

  bool get _supportsMerchantCode =>
      _collectionCountry?.supportsMomoCode ?? false;

  String get _recipientLabel =>
      _recipientType == PaymentRecipientType.code ? 'MOMO CODE' : 'MOMO NUMBER';

  String get _recipientHint {
    final country = _collectionCountry;
    if (_recipientType == PaymentRecipientType.code) {
      return country?.momoCodeExample ?? '123456';
    }

    return country?.mobileExampleE164 ??
        country?.mobileExampleNational ??
        '+250 7XX XXX XXX';
  }

  String get _recipientHelperText {
    final country = _collectionCountry;
    if (_recipientType == PaymentRecipientType.code) {
      final codeKind = country?.momoCodeKind?.trim();
      final codeLabel = switch (codeKind?.toLowerCase()) {
        'agent' => 'agent code',
        'merchant' => 'merchant code',
        _ => 'collection code',
      };
      return 'Supporters will pay this circle using the club $codeLabel.';
    }

    return 'Supporters will pay this circle to the selected mobile money number.';
  }

  void _setRecipientType(PaymentRecipientType value) {
    if (_recipientType == value) {
      return;
    }

    setState(() => _recipientType = value);
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
        paymentRecipientType: _recipientType,
        deadline: _deadline,
        isRecurring: _isRecurring,
        createdAt: DateTime.now(),
      );

      final created = await repo.createContributionGroup(group);
      try {
        await repo.recordFetEvent(
          userId: user.id,
          eventType: FetEventType.createGroup,
          metadata: <String, Object?>{'group_id': created.id},
        );
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'CreateGroupScreen',
          'Circle FET logging failed after successful creation: $error',
        );
        AfriLogger.error(
          'CreateGroupScreen',
          'Create group FET logging stack trace: $stackTrace',
          error,
          stackTrace,
        );
      }

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
    final previewRecipient = _recipientController.text.trim();
    final recipientPreviewLabel = _recipientType == PaymentRecipientType.code
        ? 'Code'
        : 'Number';

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
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          children: [
            AfriInputField(
              label: 'Group name',
              controller: _nameController,
              hint: 'APR Final Away Convoy',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriInputField(
              label: 'Purpose',
              controller: _purposeController,
              hint: 'Transport, tickets, and tifo',
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriInputField(
              label: 'Target amount',
              controller: _targetController,
              hint: '${context.afriCurrencySymbol} 500,000',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COLLECTION ROUTE',
                    style: TypographyTokens.labelSmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    'Show the circle collection destination up front.',
                    style: TypographyTokens.bodySmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children: [
                      ChoiceChip(
                        selected:
                            _recipientType == PaymentRecipientType.phoneNumber,
                        label: const Text('MOMO NUMBER'),
                        onSelected: (_) =>
                            _setRecipientType(PaymentRecipientType.phoneNumber),
                      ),
                      if (_supportsMerchantCode)
                        ChoiceChip(
                          selected: _recipientType == PaymentRecipientType.code,
                          label: const Text('MOMO CODE'),
                          onSelected: (_) =>
                              _setRecipientType(PaymentRecipientType.code),
                        ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SpacingTokens.spacing4),
                    decoration: BoxDecoration(
                      color: ColorTokens.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: BorderTokens.all(
                        color: ColorTokens.ghostBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _recipientType == PaymentRecipientType.code
                                    ? Icons.dialpad_rounded
                                    : Icons.smartphone_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _recipientLabel,
                                    style: TypographyTokens.monolithFont(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: ColorTokens.onSurface,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _recipientHelperText,
                                    style: TypographyTokens.bodySmall(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        AfriInputField(
                          controller: _recipientController,
                          label: _recipientLabel,
                          hint: _recipientHint,
                          keyboardType:
                              _recipientType == PaymentRecipientType.code
                              ? TextInputType.number
                              : TextInputType.phone,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
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
                  const Icon(AfriIcons.calendar),
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
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    previewRecipient.isEmpty
                        ? 'Collection $recipientPreviewLabel not set yet'
                        : 'Collection $recipientPreviewLabel: $previewRecipient',
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

// _ContributionInput removed — replaced by AfriInputField.
