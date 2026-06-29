import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<bool> showDeleteAccountConfirmDialog(BuildContext context) async {
  final controller = TextEditingController();
  var canDelete = false;

  final result = await showDialog<bool>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AfriDialog(
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
                      child: const Icon(
                        AfriIcons.warning,
                        color: ColorTokens.error,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Text(
                        'DELETE YOUR ACCOUNT?',
                        style: TypographyTokens.headlineMedium().copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  'Permanently deletes your profile, FET, badges, and history. Cannot be undone.',
                  style: TypographyTokens.bodyMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                Text(
                  'TYPE DELETE TO CONFIRM',
                  style: TypographyTokens.labelSmall(),
                ),
                const SizedBox(height: SpacingTokens.spacing2),
                AfriInputField(
                  controller: controller,
                  onChanged: (value) {
                    setState(
                      () => canDelete = value.trim().toUpperCase() == 'DELETE',
                    );
                  },
                  hint: 'DELETE',
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                AfriOutlinedButton(
                  onPressed: () => context.pop(false),
                  style: AfriOutlinedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      SizeTokens.buttonMinHeight,
                    ),
                  ),
                  child: const Text('CANCEL'),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                AfriButton(
                  label: 'Delete permanently',
                  fullWidth: true,
                  onTap: canDelete ? () => context.pop(true) : () {},
                  enabled: canDelete,
                ),
              ],
            ),
          );
        },
      );
    },
  );

  controller.dispose();
  return result ?? false;
}

Future<bool> showNotificationPermissionModal(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: ColorTokens.scrim,
    builder: (context) {
      return AfriDialog(
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
              'STAY IN THE GAME',
              style: TypographyTokens.headlineLarge().copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(
              'Get notified for matches, contributions, FET milestones, and club news.',
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            const _BenefitRow(label: 'Match alerts before kickoff'),
            const _BenefitRow(label: 'Contribution and ticket updates'),
            const _BenefitRow(label: 'FET milestones and challenge drops'),
            const SizedBox(height: SpacingTokens.spacing5),
            AfriButton(
              label: 'Enable notifications',
              fullWidth: true,
              onTap: () => context.pop(true),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            AfriTextButton(
              onPressed: () => context.pop(false),
              child: const Text('MAYBE LATER'),
            ),
          ],
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
      return Column(
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
            'SIGN OUT?',
            style: TypographyTokens.headlineMedium().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'Your profile and FET are saved. Sign back in anytime.',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriOutlinedButton(
            onPressed: () => context.pop(true),
            style: AfriOutlinedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                SizeTokens.buttonMinHeight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: ShapeTokens.buttonRadius,
              ),
            ),
            child: const Text('SIGN OUT'),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: 'Stay',
            fullWidth: true,
            onTap: () => context.pop(false),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<bool> showSignOutOtherDevicesSheet(BuildContext context) async {
  final result = await showAfriBottomSheet<bool>(
    context: context,
    builder: (context) {
      return Column(
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
            'SIGN OUT OTHER DEVICES?',
            style: TypographyTokens.headlineMedium().copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'This device stays signed in. Other sessions are revoked.',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          AfriOutlinedButton(
            onPressed: () => context.pop(true),
            style: AfriOutlinedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                SizeTokens.buttonMinHeight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: ShapeTokens.buttonRadius,
              ),
            ),
            child: const Text('SIGN OUT OTHERS'),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          AfriButton(
            label: 'Cancel',
            fullWidth: true,
            onTap: () => context.pop(false),
          ),
        ],
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
          const Icon(
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
