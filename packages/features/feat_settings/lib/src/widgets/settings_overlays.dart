import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool> showDeleteAccountConfirmDialog(BuildContext context) async {
  final controller = TextEditingController();
  var canDelete = false;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ColorTokens.error.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.warning_rounded,
                          color: ColorTokens.error,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: Text(
                          'DELETE YOUR ACCOUNT?',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: ColorTokens.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    'Permanently deletes your profile, XP, badges, and history. Cannot be undone.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    'TYPE DELETE TO CONFIRM',
                    style: TypographyTokens.labelSmall(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  TextField(
                    controller: controller,
                    onChanged: (value) {
                      setState(
                        () =>
                            canDelete = value.trim().toUpperCase() == 'DELETE',
                      );
                    },
                    decoration: const InputDecoration(hintText: 'DELETE'),
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  ClaymorphicButton(
                    label: 'DELETE PERMANENTLY',
                    width: double.infinity,
                    color: ColorTokens.error,
                    onPressed: canDelete
                        ? () => Navigator.of(context).pop(true)
                        : null,
                  ),
                ],
              ),
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
      return Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          animate: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: ColorTokens.clubPrimary,
                size: 56,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'STAY IN THE GAME',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: ColorTokens.onSurface,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                'Get notified for matches, contributions, XP milestones, and club news.',
                textAlign: TextAlign.center,
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              const _BenefitRow(label: 'Match alerts before kickoff'),
              const _BenefitRow(label: 'Contribution and ticket updates'),
              const _BenefitRow(label: 'XP milestones and challenge drops'),
              const SizedBox(height: SpacingTokens.spacing5),
              ClaymorphicButton(
                label: 'ENABLE NOTIFICATIONS',
                width: double.infinity,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('MAYBE LATER'),
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
      return Column(
        mainAxisSize: MainAxisSize.min,
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
            'SIGN OUT?',
            style: GoogleFonts.barlowCondensed(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'Your profile and XP are saved. Sign back in anytime.',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('SIGN OUT'),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ClaymorphicButton(
            label: 'STAY',
            width: double.infinity,
            onPressed: () => Navigator.of(context).pop(false),
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
            'SIGN OUT OTHER DEVICES?',
            style: GoogleFonts.barlowCondensed(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(
            'This device stays signed in. Other sessions are revoked.',
            textAlign: TextAlign.center,
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing5),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('SIGN OUT OTHERS'),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          ClaymorphicButton(
            label: 'CANCEL',
            width: double.infinity,
            onPressed: () => Navigator.of(context).pop(false),
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
            Icons.check_circle_rounded,
            color: ColorTokens.success,
            size: 18,
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          Expanded(child: Text(label, style: TypographyTokens.bodyMedium())),
        ],
      ),
    );
  }
}
