import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

Future<bool> showDeleteAccountConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) => const _DeleteAccountDialog(),
  );

  return result ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return AfriDialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: SizeTokens.iconXl,
                  height: SizeTokens.iconXl,
                  decoration: BoxDecoration(
                    color: ColorTokens.error.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(AfriIcons.warning, color: ColorTokens.error),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: Text(
                    l10n.settingsDeleteAccountTitle,
                    style: TypographyTokens.headlineMedium().copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.settingsDeleteAccountMessage,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.settingsDeleteAccountConfirmPrompt,
              style: TypographyTokens.labelSmall(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            AfriInputField(
              controller: _controller,
              onChanged: (value) {
                setState(
                  () => _canDelete =
                      value.trim().toUpperCase() ==
                      l10n.settingsDeleteAccountConfirmValue,
                );
              },
              hint: l10n.settingsDeleteAccountConfirmValue,
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriOutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: AfriOutlinedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  SizeTokens.buttonMinHeight,
                ),
              ),
              child: Text(l10n.settingsCancelUpper),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: l10n.settingsDeletePermanently,
              fullWidth: true,
              onTap: _canDelete ? () => Navigator.of(context).pop(true) : () {},
              enabled: _canDelete,
              variant: AfriButtonVariant.destructive,
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showNotificationPermissionModal(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      final l10n = context.afriL10n;
      return AfriDialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AfriIcons.notificationsActive,
                color: ColorTokens.clubPrimary,
                size: SizeTokens.iconXxl,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                l10n.settingsNotificationPermissionTitle,
                style: TypographyTokens.headlineLarge().copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                l10n.settingsNotificationPermissionMessage,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              _BenefitRow(label: l10n.settingsMatchAlerts),
              _BenefitRow(label: l10n.settingsContributionUpdates),
              _BenefitRow(label: l10n.settingsFetMilestones),
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                label: l10n.settingsEnableNotifications,
                fullWidth: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.settingsMaybeLaterUpper),
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}

Future<bool> showSignOutConfirmationSheet(BuildContext context) async {
  final result = await showAfriBottomSheet<bool>(
    context: context,
    builder: (context) {
      final l10n = context.afriL10n;
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: SizeTokens.sheetHandleWidth,
                height: SizeTokens.sheetHandleHeight,
                decoration: BoxDecoration(
                  color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: ShapeTokens.buttonRadius,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.settingsSignOutTitle,
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              l10n.settingsSignOutMessage,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: l10n.settingsSignOut,
              fullWidth: true,
              variant: AfriButtonVariant.destructive,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: l10n.settingsStay,
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      );
    },
  );

  return result ?? false;
}

Future<bool> showSignOutOtherDevicesSheet(BuildContext context) async {
  final result = await showAfriBottomSheet<bool>(
    context: context,
    builder: (context) {
      final l10n = context.afriL10n;
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: SizeTokens.sheetHandleWidth,
                height: SizeTokens.sheetHandleHeight,
                decoration: BoxDecoration(
                  color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
                  borderRadius: ShapeTokens.buttonRadius,
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              l10n.settingsSignOutOthersTitle,
              style: TypographyTokens.headlineMedium().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              l10n.settingsSignOutOthersMessage,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriOutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: AfriOutlinedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  SizeTokens.buttonMinHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: ShapeTokens.buttonRadius,
                ),
              ),
              child: Text(l10n.settingsSignOutOthersAction),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriButton(
              label: l10n.settingsCancel,
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      );
    },
  );

  return result ?? false;
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: Row(
        children: [
          Icon(
            AfriIcons.statusSuccess,
            color: ColorTokens.success,
            size: SizeTokens.iconSm,
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          Expanded(child: Text(label, style: TypographyTokens.bodyMedium())),
        ],
      ),
    );
  }
}
