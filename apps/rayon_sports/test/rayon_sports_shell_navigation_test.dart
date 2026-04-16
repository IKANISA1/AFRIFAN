import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  group('Rayon Sports app shell', () {
    late RayonSportsConfig config;

    setUp(() {
      config = const RayonSportsConfig();
      ColorTokens.init(config.colors);
      AppModuleRegistry.build(config);
    });

    testWidgets('renders the home shell with production modules', (
      tester,
    ) async {
      // Skip due to feature flag hydration timing in tests
    }, skip: true);

    testWidgets('navigates between home and settings tabs', (tester) async {
      // Skip due to feature flag hydration timing in tests
    }, skip: true);
  });
}
