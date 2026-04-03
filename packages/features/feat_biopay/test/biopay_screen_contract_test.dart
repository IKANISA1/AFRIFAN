import 'package:core_auth/core_auth.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hub preserves the core BioPay pay and receive contract', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biopayProfileProvider.overrideWith((ref) => null),
          biopayEnabledProvider.overrideWith((ref) => true),
          currentUserProvider.overrideWith(
            (ref) => const UserProfile(
              id: 'user-1',
              clubId: 'rayon_sports_rw',
              publicUserId: '483912',
              phone: '0788123456',
              momoNumber: '0788123456',
              momoProvider: 'MoMo',
            ),
          ),
        ],
        child: const MaterialApp(home: BioPayScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('BIOPAY'), findsOneWidget);
    expect(find.text('How you want\nto pay today'), findsOneWidget);
    expect(find.text('Face Scan'), findsOneWidget);
    expect(find.text('NFC Tap'), findsOneWidget);
    expect(find.text('Get QR'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
  });
}
