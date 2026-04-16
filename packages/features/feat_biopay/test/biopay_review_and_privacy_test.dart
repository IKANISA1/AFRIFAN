import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BioPay privacy surfaces', () {
    test('profile exposes alias-first public values', () {
      const profile = BioPayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Marie Uwase',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781234567',
        countryCode: 'RW',
        active: true,
        consentVersion: 'BioPay-v1',
      );

      expect(profile.formattedAlias, '483-912');
      expect(profile.maskedRecipientValue, '078•••567');
    });

    testWidgets('handoff review renders the clean tap-to-dial confirmation', (
      tester,
    ) async {
      final resolution = BioPayHandoffResolution(
        displayName: 'Marie Uwase',
        publicId: '483912',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781234567',
        countryCode: 'RW',
        paymentCode: '*182*1*1*0781234567#',
        paymentMethod: 'ussd_dial',
        expiresAt: DateTime(2026, 3, 31, 12),
        channel: 'qr',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BioPayPaymentReviewScreen(
              args: BioPayPaymentReviewArgs.handoff(
                source: BioPayReviewSource.qrScan,
                handoffResolution: resolution,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0781234567'), findsOneWidget);
      expect(find.text('Tap to Dial'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('BioPay review flow', () {
    testWidgets('face match review keeps the minimal confirmation layout', (
      tester,
    ) async {
      const profile = BioPayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Marie Uwase',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781234567',
        countryCode: 'RW',
        active: true,
        consentVersion: 'BioPay-v1',
      );

      const matchResult = BioPayMatchResult(
        match: true,
        score: 0.97,
        profile: profile,
        matchReceipt: 'signed-match-receipt',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BioPayPaymentReviewScreen(
              args: BioPayPaymentReviewArgs.faceMatch(matchResult: matchResult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0781234567'), findsOneWidget);
      expect(find.text('Tap to Dial'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
