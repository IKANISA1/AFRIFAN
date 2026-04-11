import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:feat_membership/src/screens/membership_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadDesignFonts);

  testWidgets('matches the membership tier surface layout', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          supabaseClientProvider.overrideWithValue(
            SupabaseClient(
              'https://example.supabase.co',
              'anon-key',
              authOptions: const FlutterAuthClientOptions(
                autoRefreshToken: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: MembershipScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MembershipScreen),
      matchesGoldenFile('goldens/membership_screen.png'),
    );
  });
}
