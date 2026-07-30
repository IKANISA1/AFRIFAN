import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClubScope', () {
    test('isResolved returns true when clubId is set', () {
      const scope = ClubScope(partnerId: '', clubId: 42);
      expect(scope.isResolved, isTrue);
    });

    test('partner metadata alone does not resolve club tenancy', () {
      const scope = ClubScope(partnerId: 'rayon-sports', clubId: null);
      expect(scope.isResolved, isFalse);
    });

    test('isResolved returns false when both are empty/null', () {
      const scope = ClubScope(partnerId: '', clubId: null);
      expect(scope.isResolved, isFalse);
    });

    test('requiredClubId fails closed without a positive club id', () {
      const scope = ClubScope(partnerId: 'legacy-partner', clubId: null);
      expect(() => scope.requiredClubId, throwsStateError);
    });
  });

  group('ClubScope write payload', () {
    test('always includes club_id and may retain partner metadata', () {
      const scope = ClubScope(partnerId: 'cool', clubId: 7);
      expect(scope.toWritePayload(), {'club_id': 7, 'partner_id': 'cool'});
    });

    test('refuses a partner-only write payload', () {
      const scope = ClubScope(partnerId: 'test-partner', clubId: null);
      expect(scope.toWritePayload, throwsStateError);
    });

    test('refuses an unresolved write payload', () {
      const scope = ClubScope(partnerId: '', clubId: null);
      expect(scope.toWritePayload, throwsStateError);
    });
  });

  group('ClubScopeResolver tenant selection', () {
    test('uses the first valid positive club id candidate', () {
      expect(
        ClubScopeResolver.firstValidClubId([null, '', 'invalid', '24', '99']),
        24,
      );
    });

    test('rejects zero and negative club scopes', () {
      expect(ClubScopeResolver.firstValidClubId(['0', '-1', null]), isNull);
    });
  });

  group('SupabaseClientFactory', () {
    test('isInitialized is false before init', () {
      expect(SupabaseClientFactory.isInitialized, isFalse);
    });

    test('throws on client access before init', () {
      // Accessing client before initialization should throw.
      expect(() => SupabaseClientFactory.client, throwsA(isA<Error>()));
    });
  });
}
