import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

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
                    style: TypographyTokens.monolithFont(
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
                  AfriButton(
                    label: 'Enable',
                    fullWidth: true,
                    onTap: () => Navigator.of(context).pop(true),
                    enabled: allowReading,
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
