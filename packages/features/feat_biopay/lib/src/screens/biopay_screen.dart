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
        .watch(BioPayEnabledProvider)
        .maybeWhen(data: (value) => value, orElse: () => true);
    final showBackButton = Navigator.of(context).canPop();

    return KillSwitchGate(
      enabled: isEnabled,
      featureName: 'BioPay',
      child: Scaffold(
        backgroundColor: BioPayReferenceBackground,
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
                        BioPayReferenceLightBackButton(onTap: context.pop)
                      else
                        const SizedBox(width: 44, height: 44),
                      const Spacer(),
                      BioPayReferenceProfileButton(
                        onTap: () => context.push('/BioPay/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Pay and get paid\ninstantly',
                    style: BioPayReferenceText(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
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
                        BioPayReferenceHomeTile(
                          icon: AfriIcons.faceScan,
                          color: BioPayReferenceBlue,
                          label: 'Face Scan',
                          onTap: () => context.push('/BioPay/scan?mode=pay'),
                        ),
                        BioPayReferenceHomeTile(
                          icon: AfriIcons.nfc,
                          color: BioPayReferencePurple,
                          label: 'NFC Tap',
                          onTap: () => context.push('/BioPay/nfc'),
                        ),
                        BioPayReferenceHomeTile(
                          icon: AfriIcons.qrCode,
                          color: BioPayReferenceOrange,
                          label: 'Get QR',
                          onTap: () => context.push('/BioPay/qr'),
                        ),
                        BioPayReferenceHomeTile(
                          icon: AfriIcons.qrScan,
                          color: BioPayReferenceTeal,
                          label: 'Scan QR',
                          onTap: () => context.push('/BioPay/qr/scan'),
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
