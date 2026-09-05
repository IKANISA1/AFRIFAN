import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<bool> showSmsPermissionModal(BuildContext context) async {
  var allowReading = false;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AfriDialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ColorTokens.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AfriIcons.sms,
                    color: ColorTokens.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  context.afriL10n.contributionsEnableMomoSmsTitle,
                  style: TypographyTokens.headlineLarge().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  context.afriL10n.contributionsSmsPrivacyMessage(
                    RuntimeBranding.displayAppName,
                  ),
                  textAlign: TextAlign.center,
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                AfriSwitchListTile(
                  value: allowReading,
                  activeThumbColor: ColorTokens.primary,
                  title: Text(context.afriL10n.contributionsAllowSmsReading),
                  onChanged: (value) => setState(() => allowReading = value),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriButton(
                  label: context.afriL10n.contributionsEnable,
                  fullWidth: true,
                  onTap: () => context.pop(true),
                  enabled: allowReading,
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriOutlinedButton(
                  onPressed: () => context.pop(false),
                  style: AfriOutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: Text(context.afriL10n.contributionsNotNowUpper),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  return result ?? false;
}
