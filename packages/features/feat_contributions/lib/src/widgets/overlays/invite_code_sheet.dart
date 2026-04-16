import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _InviteCodeSheet extends StatelessWidget {
  const _InviteCodeSheet({required this.inviteCode, this.groupName});

  final String inviteCode;
  final String? groupName;

  String get _shareText =>
      'Join my ${RuntimeBranding.displayAppName} Group${groupName != null ? ' "$groupName"' : ''}! '
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
              'INVITE TO Group',
              style: TypographyTokens.monolithFont(
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
                border: BorderTokens.all(
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
                  color: ExternalBrandColors.whatsAppGreen,
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
                  icon: AfriIcons.share,
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
                border: BorderTokens.all(
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

            AfriButton(
              label: 'Done',
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
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
            border: BorderTokens.all(color: color, opacity: 0.2),
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
