import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BioPay privacy surfaces', () {
    test('profile exposes alias-first public values', () {
      const profile = BiopayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Marie Uwase',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781234567',
        countryCode: 'RW',
        active: true,
        consentVersion: 'biopay-v1',
      );

      expect(profile.formattedAlias, '483-912');
      expect(profile.maskedRecipientValue, '078•••567');
    });

    testWidgets('handoff review renders alias and masked route only', (
      tester,
    ) async {
      final resolution = BiopayHandoffResolution(
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
            home: BiopayPaymentReviewScreen(
              args: BiopayPaymentReviewArgs.handoff(
                source: BiopayReviewSource.qrScan,
                handoffResolution: resolution,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('483-912'), findsOneWidget);
      expect(find.text('Marie Uwase'), findsNothing);
      expect(find.textContaining('078•••567'), findsOneWidget);
      expect(find.text('0781234567'), findsNothing);
    });
  });

  group('BioPay review flow', () {
    testWidgets('face match review requires an amount before submit', (
      tester,
    ) async {
      const profile = BiopayProfile(
        id: 'profile-1',
        publicId: '483912',
        userId: 'user-1',
        displayName: 'Marie Uwase',
        routeType: PaymentRecipientType.phoneNumber,
        recipientValue: '0781234567',
        countryCode: 'RW',
        active: true,
        consentVersion: 'biopay-v1',
      );

      const matchResult = BiopayMatchResult(
        match: true,
        score: 0.97,
        profile: profile,
        matchReceipt: 'signed-match-receipt',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BiopayPaymentReviewScreen(
              args: BiopayPaymentReviewArgs.faceMatch(matchResult: matchResult),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ClaymorphicButton));
      await tester.pumpAndSettle();

      expect(find.text('Enter an amount.'), findsOneWidget);
    });
  });
}
