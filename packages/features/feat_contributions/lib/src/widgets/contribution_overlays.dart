import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full contribution flow: Amount → USSD Confirmation → Record → Success.
///
/// Uses [MomoDialerService] for dynamic USSD building and
/// [ClubRepository.contribute] to persist the contribution.
Future<void> showMomoAmountEntrySheet(
  BuildContext context, {
  required String title,
  String? groupId,
  String? recipientMomo,
}) async {
  final amount = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _AmountEntrySheet(title: title),
  );

  if (amount == null || !context.mounted) return;

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _UssdConfirmationSheet(
      amount: amount,
      title: title,
      // §2.4 LOCKED — no hardcoded MOMO. Caller must supply recipientMomo.
      recipientMomo: recipientMomo ?? '',
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // Launch the MOMO dialer with dynamic USSD
  // §2.4 LOCKED — no hardcoded MOMO fallback.
  final recipient = recipientMomo ?? '';
  await MomoDialerService.launchMomoUssd(recipient: recipient, amount: amount);

  // Record the contribution in the database
  var recordedPending = false;
  if (groupId != null && context.mounted) {
    try {
      final container = ProviderScope.containerOf(context);
      final repo = container.read(clubRepositoryProvider);
      final userId = container.read(currentUserProvider)?.id;

      if (userId != null) {
        final ref = 'MOMO-${DateTime.now().millisecondsSinceEpoch}';
        await repo.contribute(
          groupId: groupId,
          userId: userId,
          amount: amount,
          paymentReference: ref,
        );
        recordedPending = true;
      }
    } catch (e) {
      debugPrint('[ContributionOverlay] Failed to record contribution: $e');
    }
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) => _ContributionSuccessDialog(
      amount: amount,
      title: title,
      recordedPending: recordedPending,
    ),
  );
}

/// Shows the invite code bottom sheet with the real code from the group.
Future<void> showGroupInviteCodeSheet(
  BuildContext context, {
  String? inviteCode,
  String? groupName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _InviteCodeSheet(
      inviteCode: inviteCode ?? 'NO-CODE',
      groupName: groupName,
    ),
  );
}

Future<bool> showSmsPermissionModal(BuildContext context) async {
  var allowReading = false;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GlassCard(
              animate: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: ColorTokens.clubPrimary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.sms_rounded,
                      color: ColorTokens.clubPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    'ENABLE MOMO SMS SYNC',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ColorTokens.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    '${RuntimeBranding.displayAppName} reads only MoMo confirmations to auto-log receipts. No other messages are accessed.',
                    textAlign: TextAlign.center,
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  SwitchListTile(
                    value: allowReading,
                    activeThumbColor: ColorTokens.clubPrimary,
                    title: const Text('Allow SMS reading'),
                    onChanged: (value) => setState(() => allowReading = value),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ClaymorphicButton(
                    label: 'ENABLE',
                    width: double.infinity,
                    onPressed: allowReading
                        ? () => Navigator.of(context).pop(true)
                        : null,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Text('NOT NOW'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return result ?? false;
}

Future<String?> showGroupPrivacySettingsSheet(
  BuildContext context, {
  required String currentValue,
}) {
  return showAfriBottomSheet<String>(
    context: context,
    builder: (context) {
      return _GroupPrivacySettingsSheet(currentValue: currentValue);
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// Private Widgets
// ═══════════════════════════════════════════════════════════════

class _AmountEntrySheet extends StatefulWidget {
  const _AmountEntrySheet({required this.title});

  final String title;

  @override
  State<_AmountEntrySheet> createState() => _AmountEntrySheetState();
}

class _AmountEntrySheetState extends State<_AmountEntrySheet> {
  int _amount = 5000;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: 'RWF',
      currencySymbol: 'FRw',
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              'HOW MUCH TO CONTRIBUTE?',
              style: GoogleFonts.barlowCondensed(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(widget.title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              currency.format(_amount),
              style: GoogleFonts.barlowCondensed(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Wrap(
              spacing: SpacingTokens.spacing2,
              children: [1000, 2000, 5000, 10000]
                  .map(
                    (value) => ChoiceChip(
                      selected: _amount == value,
                      label: Text('+${value.toString()}'),
                      onSelected: (_) => setState(() => _amount = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            ClaymorphicButton(
              label: 'LAUNCH MOMO DIALER',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(_amount),
            ),
          ],
        ),
      ),
    );
  }
}

class _UssdConfirmationSheet extends StatelessWidget {
  const _UssdConfirmationSheet({
    required this.amount,
    required this.title,
    required this.recipientMomo,
  });

  final int amount;
  final String title;
  final String recipientMomo;

  @override
  Widget build(BuildContext context) {
    // Build dynamic USSD string from country catalog
    final country = AfriCountryCatalog.defaultCountry;
    final ussdCode = country.buildUssdCode(
      recipientMomo: recipientMomo,
      amount: amount,
    );

    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LAUNCHING MOMO',
              style: GoogleFonts.barlowCondensed(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              ussdCode,
              style: TypographyTokens.numericAlias(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing5),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('DIAL NOW'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionSuccessDialog extends StatelessWidget {
  const _ContributionSuccessDialog({
    required this.amount,
    required this.title,
    required this.recordedPending,
  });

  final int amount;
  final String title;
  final bool recordedPending;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: 'RWF',
      currencySymbol: 'FRw',
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recordedPending
                  ? Icons.hourglass_top_rounded
                  : Icons.open_in_new_rounded,
              color: recordedPending
                  ? ColorTokens.warning
                  : ColorTokens.clubAccent,
              size: 64,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              recordedPending
                  ? 'PENDING CONFIRMATION'
                  : 'PAYMENT HANDOFF STARTED',
              style: GoogleFonts.barlowCondensed(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              currency.format(amount),
              style: GoogleFonts.barlowCondensed(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(title, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              recordedPending
                  ? 'Logged as pending. Moves to confirmed after receipt match.'
                  : 'Complete the MoMo prompt. Retry from the circle if matching fails.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            ClaymorphicButton(
              label: 'BACK TO CIRCLE',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeSheet extends StatelessWidget {
  const _InviteCodeSheet({required this.inviteCode, this.groupName});

  final String inviteCode;
  final String? groupName;

  String get _shareText =>
      'Join my ${RuntimeBranding.displayAppName} circle${groupName != null ? ' "$groupName"' : ''}! '
      'Use code: $inviteCode';

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareWhatsApp() async {
    final encoded = Uri.encodeComponent(_shareText);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // WhatsApp not installed — silent fail
    }
  }

  Future<void> _shareSystem() async {
    // Use platform share sheet via SMS as fallback
    final uri = Uri(scheme: 'sms', queryParameters: {'body': _shareText});
    try {
      await launchUrl(uri);
    } catch (_) {
      // Fallback — do nothing
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      child: GlassCard(
        animate: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'INVITE TO CIRCLE',
              style: GoogleFonts.barlowCondensed(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ColorTokens.onSurface,
              ),
            ),
            if (groupName != null) ...[
              const SizedBox(height: SpacingTokens.spacing2),
              Text(groupName!, style: TypographyTokens.bodySmall()),
            ],
            const SizedBox(height: SpacingTokens.spacing4),

            // Invite code display — gold on dark glass
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: SpacingTokens.spacing4,
                horizontal: SpacingTokens.spacing5,
              ),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Center(
                child: Text(
                  inviteCode,
                  style: TypographyTokens.numericAlias(fontSize: 32),
                ),
              ),
            ),

            const SizedBox(height: SpacingTokens.spacing4),

            // Share actions row
            Row(
              children: [
                _ShareAction(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  // NOTE: WhatsApp brand color — not a club color
                  color: const Color(0xFF25D366),
                  onTap: _shareWhatsApp,
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                _ShareAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  color: ColorTokens.clubAccent,
                  onTap: () => _copyCode(context),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                _ShareAction(
                  icon: Icons.share_rounded,
                  label: 'More',
                  color: ColorTokens.onSurfaceVariant,
                  onTap: _shareSystem,
                ),
              ],
            ),

            const SizedBox(height: SpacingTokens.spacing4),

            // Validity note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SpacingTokens.spacing3),
              decoration: BoxDecoration(
                color: ColorTokens.clubAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: ColorTokens.clubAccent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Text(
                      'Code valid for 7 days',
                      style: TypographyTokens.bodySmall().copyWith(
                        color: ColorTokens.clubAccent.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: SpacingTokens.spacing4),

            ClaymorphicButton(
              label: 'DONE',
              width: double.infinity,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPrivacySettingsSheet extends StatefulWidget {
  const _GroupPrivacySettingsSheet({required this.currentValue});

  final String currentValue;

  @override
  State<_GroupPrivacySettingsSheet> createState() =>
      _GroupPrivacySettingsSheetState();
}

class _GroupPrivacySettingsSheetState
    extends State<_GroupPrivacySettingsSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const options = <_PrivacyOptionData>[
      _PrivacyOptionData(
        value: 'PUBLIC',
        title: 'PUBLIC',
        description: 'Anyone can see the circle and request to join.',
        icon: Icons.public_rounded,
      ),
      _PrivacyOptionData(
        value: 'FRIENDS OF MEMBERS',
        title: 'FRIENDS OF MEMBERS',
        description:
            'Only supporters connected to members can join via invite.',
        icon: Icons.groups_rounded,
      ),
      _PrivacyOptionData(
        value: 'PRIVATE',
        title: 'PRIVATE',
        description: 'Invite code and approval are both required.',
        icon: Icons.lock_rounded,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Text(
          'CIRCLE PRIVACY',
          style: GoogleFonts.barlowCondensed(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ColorTokens.onSurface,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          'Choose who can discover this circle and request to join.',
          style: TypographyTokens.bodyMedium(),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
            child: _PrivacyOptionCard(
              data: option,
              selected: _value == option.value,
              onTap: () => setState(() => _value = option.value),
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        const GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacyCompareRow(
                visibility: 'VISIBILITY',
                join: 'JOIN',
                approval: 'APPROVAL',
                heading: true,
              ),
              SizedBox(height: SpacingTokens.spacing2),
              _PrivacyCompareRow(
                visibility: 'Public',
                join: 'Request',
                approval: 'Optional',
              ),
              SizedBox(height: SpacingTokens.spacing1),
              _PrivacyCompareRow(
                visibility: 'Friends',
                join: 'Invite',
                approval: 'Member-led',
              ),
              SizedBox(height: SpacingTokens.spacing1),
              _PrivacyCompareRow(
                visibility: 'Private',
                join: 'Code',
                approval: 'Required',
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        ClaymorphicButton(
          label: 'SAVE',
          width: double.infinity,
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

class _PrivacyOptionCard extends StatelessWidget {
  const _PrivacyOptionCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _PrivacyOptionData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ColorTokens.clubPrimary : ColorTokens.ghostBorder,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ColorTokens.clubPrimary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? ColorTokens.clubPrimary.withValues(alpha: 0.14)
                    : ColorTokens.glassFill,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                data.icon,
                color: selected
                    ? ColorTokens.clubPrimary
                    : ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(data.description, style: TypographyTokens.bodyMedium()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCompareRow extends StatelessWidget {
  const _PrivacyCompareRow({
    required this.visibility,
    required this.join,
    required this.approval,
    this.heading = false,
  });

  final String visibility;
  final String join;
  final String approval;
  final bool heading;

  @override
  Widget build(BuildContext context) {
    final style = heading
        ? TypographyTokens.labelSmall().copyWith(
            color: ColorTokens.onSurfaceVariant,
          )
        : TypographyTokens.bodySmall();
    return Row(
      children: [
        Expanded(flex: 4, child: Text(visibility, style: style)),
        Expanded(flex: 3, child: Text(join, style: style)),
        Expanded(flex: 3, child: Text(approval, style: style)),
      ],
    );
  }
}

class _PrivacyOptionData {
  const _PrivacyOptionData({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: SpacingTokens.spacing1),
              Text(
                label,
                style: TypographyTokens.labelSmall().copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
