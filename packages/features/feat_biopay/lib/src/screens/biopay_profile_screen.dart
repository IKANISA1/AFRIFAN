import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_profile.dart';
import '../providers/biopay_providers.dart';
import '../widgets/biopay_reference_ui.dart';

class BiopayProfileScreen extends ConsumerStatefulWidget {
  const BiopayProfileScreen({super.key});

  @override
  ConsumerState<BiopayProfileScreen> createState() =>
      _BiopayProfileScreenState();
}

class _BiopayProfileScreenState extends ConsumerState<BiopayProfileScreen> {
  PaymentRecipientType? _selectedRouteType;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(biopayProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final selectedRouteType =
        _selectedRouteType ??
        profile?.routeType ??
        PaymentRecipientType.phoneNumber;
    final bioPayId = _bioPayId(profile, user);
    final displayedValue = _valueForRoute(selectedRouteType, profile, user);
    final displayedLabel = selectedRouteType == PaymentRecipientType.code
        ? 'Merchant Code'
        : 'MoMo Number';

    return BiopayReferencePage(
      title: 'Profile',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/biopay');
        }
      },
      child: ListView(
        children: [
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: biopayReferencePanelDecoration(radius: 30),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: Color(0xFF94A4BF),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              bioPayId,
              style: biopayReferenceText(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'BIOPAY ID',
              style: biopayReferenceText(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: biopayReferenceMuted,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 36),
          BiopayReferenceSegmentedControl(
            selected: selectedRouteType,
            onChanged: (value) => setState(() => _selectedRouteType = value),
          ),
          const SizedBox(height: 22),
          BiopayReferenceValueCard(
            label: displayedLabel,
            value: displayedValue,
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => context.push('/biopay/register'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(26, 22, 24, 22),
              decoration: biopayReferencePanelDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Face ID',
                          style: biopayReferenceText(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile != null ? 'Ready' : 'Set Up',
                          style: biopayReferenceText(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: profile != null
                                ? biopayReferenceGreen
                                : biopayReferenceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: biopayReferenceInk,
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

  String _bioPayId(BiopayProfile? profile, UserProfile? user) {
    return profile?.publicId.trim().isNotEmpty == true
        ? profile!.publicId
        : (user?.publicUserId?.trim().isNotEmpty == true
              ? user!.publicUserId!
              : '882931');
  }

  String _valueForRoute(
    PaymentRecipientType routeType,
    BiopayProfile? profile,
    UserProfile? user,
  ) {
    if (routeType == PaymentRecipientType.code) {
      if (profile?.routeType == PaymentRecipientType.code &&
          (profile?.recipientValue.trim().isNotEmpty ?? false)) {
        return profile!.recipientValue;
      }
      return '23456';
    }

    if (profile?.routeType == PaymentRecipientType.phoneNumber &&
        (profile?.recipientValue.trim().isNotEmpty ?? false)) {
      return profile!.recipientValue;
    }

    final momo = user?.momoNumber?.trim();
    return (momo != null && momo.isNotEmpty) ? momo : '0788123456';
  }
}
