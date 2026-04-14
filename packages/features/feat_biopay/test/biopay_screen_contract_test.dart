import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadDesignFonts);

  testWidgets('hub preserves the approved BioPay home layout', (tester) async {
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

    expect(find.text('Pay & Get Paid\nInstantly'), findsOneWidget);
    expect(find.text('Face Scan'), findsOneWidget);
    expect(find.text('NFC Tap'), findsOneWidget);
    expect(find.text('Get QR'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, equals(ColorTokens.background));
  });

  testWidgets('matches the approved BioPay command grid', (tester) async {
    _setMobileSurface(tester);

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

    await expectLater(
      find.byType(BioPayScreen),
      matchesGoldenFile('goldens/biopay_screen.png'),
    );
  });
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
