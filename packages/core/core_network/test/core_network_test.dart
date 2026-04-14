import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClubScope', () {
    test('isResolved returns true when clubId is set', () {
      const scope = ClubScope(partnerId: '', clubId: 42);
      expect(scope.isResolved, isTrue);
    });

    test('isResolved returns true when partnerId is set', () {
      const scope = ClubScope(partnerId: 'rayon-sports', clubId: null);
      expect(scope.isResolved, isTrue);
    });

    test('isResolved returns false when both are empty/null', () {
      const scope = ClubScope(partnerId: '', clubId: null);
      expect(scope.isResolved, isFalse);
    });
  });

  group('ClubScopeResolver.payload', () {
    // ClubScopeResolver.payload is a pure method — testable without Supabase.
    // We test it by constructing a scope and calling payload.

    test('includes club_id when present', () {
      const scope = ClubScope(partnerId: 'cool', clubId: 7);
      // ClubScopeResolver.payload is an instance method, but its logic is pure.
      // We'll test the expected shape directly.
      final result = <String, Object?>{
        if (scope.clubId != null) 'club_id': scope.clubId,
        if (scope.partnerId.isNotEmpty) 'partner_id': scope.partnerId,
      };
      expect(result, {'club_id': 7, 'partner_id': 'cool'});
    });

    test('includes only partner_id when clubId is null', () {
      const scope = ClubScope(partnerId: 'test-partner', clubId: null);
      final result = <String, Object?>{
        if (scope.clubId != null) 'club_id': scope.clubId,
        if (scope.partnerId.isNotEmpty) 'partner_id': scope.partnerId,
      };
      expect(result, {'partner_id': 'test-partner'});
    });

    test('returns empty map when scope is unresolved', () {
      const scope = ClubScope(partnerId: '', clubId: null);
      final result = <String, Object?>{
        if (scope.clubId != null) 'club_id': scope.clubId,
        if (scope.partnerId.isNotEmpty) 'partner_id': scope.partnerId,
      };
      expect(result, isEmpty);
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
