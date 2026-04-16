import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../biopay_display_resolver.dart';
import '../biopay_tokens.dart';
import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';

class BioPayProfileScreen extends ConsumerStatefulWidget {
  const BioPayProfileScreen({super.key});

  @override
  ConsumerState<BioPayProfileScreen> createState() =>
      _BioPayProfileScreenState();
}

class _BioPayProfileScreenState extends ConsumerState<BioPayProfileScreen> {
  PaymentRecipientType? _selectedRouteType;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(BioPayProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final selectedRouteType =
        _selectedRouteType ??
        profile?.routeType ??
        PaymentRecipientType.phoneNumber;
    final BioPayId = resolveBioPayId(profile, user) ?? kBioPayUnlinkedLabel;
    final displayedValue =
        resolveBioPayRouteValue(selectedRouteType, profile, user) ??
        kBioPayUnlinkedLabel;
    final displayedLabel = selectedRouteType == PaymentRecipientType.code
        ? 'Saved Face ID Code'
        : 'Saved Face ID Number';

    return BioPayReferencePage(
      title: 'Profile',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/BioPay');
        }
      },
      child: ListView(
        children: [
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BioPayReferencePanelDecoration(radius: 30),
              child: Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: BioPayTokens.iconMuted,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              BioPayId,
              style: BioPayReferenceText(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'BioPay ID',
              style: BioPayReferenceText(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: BioPayReferenceMuted,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 36),
          BioPayReferenceSegmentedControl(
            selected: selectedRouteType,
            onChanged: (value) => setState(() => _selectedRouteType = value),
          ),
          const SizedBox(height: 22),
          BioPayReferenceValueCard(
            label: displayedLabel,
            value: displayedValue,
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => context.push('/BioPay/register'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(26, 22, 24, 22),
              decoration: BioPayReferencePanelDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Face ID',
                          style: BioPayReferenceText(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile != null ? 'Ready' : 'Set Up',
                          style: BioPayReferenceText(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: profile != null
                                ? BioPayReferenceGreen
                                : BioPayReferenceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: BioPayReferenceInk,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
