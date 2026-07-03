import 'package:core_theme/src/runtime_branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeBranding', () {
    setUp(RuntimeBranding.resetForTest);

    test('prefers configured app and club identities', () {
      RuntimeBranding.configure(
        appName: 'Gikundiro',
        clubName: 'Rayon Sports FC',
      );

      expect(RuntimeBranding.displayAppName, 'Gikundiro');
      expect(RuntimeBranding.displayClubName, 'Rayon Sports FC');
      expect(RuntimeBranding.appInitials, 'GI');
    });

    test('does not fall back to AFRICLUB placeholder branding', () {
      RuntimeBranding.configure(appName: '', clubName: 'Rayon Sports FC');

      expect(RuntimeBranding.displayAppName, 'Rayon Sports FC');
      expect(RuntimeBranding.displayClubName, 'Rayon Sports FC');
      expect(RuntimeBranding.appInitials, 'RS');
      expect(RuntimeBranding.displayAppName, isNot('AFRICLUB'));
      expect(RuntimeBranding.displayClubName, isNot('AFRICLUB'));
    });
  });
}
