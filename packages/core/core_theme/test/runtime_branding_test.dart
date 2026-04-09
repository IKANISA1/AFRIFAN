import 'package:core_theme/src/runtime_branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeBranding', () {
    setUp(RuntimeBranding.resetForTest);

    test('prefers configured app and club identities', () {
      RuntimeBranding.configure(
        appName: 'Gikundiro',
        clubName: 'Rayon Sports FC',
        crestAsset: 'assets/crest/rayon_sports_crest.png',
      );

      expect(RuntimeBranding.displayAppName, 'Gikundiro');
      expect(RuntimeBranding.displayClubName, 'Rayon Sports FC');
      expect(RuntimeBranding.appInitials, 'GI');
      expect(
        RuntimeBranding.displayCrestAsset,
        'assets/crest/rayon_sports_crest.png',
      );
    });

    test('does not fall back to AFRICLUB placeholder branding', () {
      RuntimeBranding.configure(
        appName: '',
        clubName: 'Rayon Sports FC',
        crestAsset: '',
      );

      expect(RuntimeBranding.displayAppName, 'Rayon Sports FC');
      expect(RuntimeBranding.displayClubName, 'Rayon Sports FC');
      expect(RuntimeBranding.appInitials, 'RS');
      expect(RuntimeBranding.displayAppName, isNot('AFRICLUB'));
      expect(RuntimeBranding.displayClubName, isNot('AFRICLUB'));
    });
  });
}
