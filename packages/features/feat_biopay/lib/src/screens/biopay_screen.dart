import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';

/// BioPay home screen aligned to the approved clean reference layout.
class BioPayScreen extends ConsumerWidget {
  const BioPayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref
        .watch(biopayEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);
    final showBackButton = Navigator.of(context).canPop();

    return KillSwitchGate(
      enabled: isEnabled,
      featureName: 'BioPay',
      child: Scaffold(
        backgroundColor: biopayReferenceBackground,
        body: GradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBackButton)
                        BiopayReferenceLightBackButton(onTap: context.pop)
                      else
                        const SizedBox(width: 44, height: 44),
                      const Spacer(),
                      BiopayReferenceProfileButton(
                        onTap: () => context.push('/biopay/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Pay & Get Paid\nInstantly',
                    style: biopayReferenceText(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 22,
                      mainAxisSpacing: 22,
                      childAspectRatio: 0.92,
                      children: [
                        BiopayReferenceHomeTile(
                          icon: Icons.face_retouching_natural_rounded,
                          color: biopayReferenceBlue,
                          label: 'Face Scan',
                          onTap: () => context.push('/biopay/scan?mode=pay'),
                        ),
                        BiopayReferenceHomeTile(
                          icon: Icons.nfc_rounded,
                          color: biopayReferencePurple,
                          label: 'NFC Tap',
                          onTap: () => context.push('/biopay/nfc'),
                        ),
                        BiopayReferenceHomeTile(
                          icon: Icons.qr_code_2_rounded,
                          color: biopayReferenceOrange,
                          label: 'Get QR',
                          onTap: () => context.push('/biopay/qr'),
                        ),
                        BiopayReferenceHomeTile(
                          icon: Icons.qr_code_scanner_rounded,
                          color: biopayReferenceTeal,
                          label: 'Scan QR',
                          onTap: () => context.push('/biopay/qr/scan'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
