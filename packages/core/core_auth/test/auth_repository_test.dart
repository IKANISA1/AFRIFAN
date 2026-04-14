import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository.resolveAdminAccess', () {
    test('normalizes platform and partner assignments from the database', () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'assignment-1',
            'user_id': 'user-1',
            'role': 'super_admin',
            'club_id': 24,
            'assigned_by': 'seed',
            'created_at': '2026-04-14T12:00:00.000Z',
            'is_active': true,
          },
          <String, dynamic>{
            'id': 'assignment-2',
            'user_id': 'user-1',
            'role': 'club_admin',
            'club_id': 99,
            'assigned_by': 'seed',
            'created_at': '2026-04-14T12:05:00.000Z',
            'is_active': true,
          },
        ],
      );

      final access = await repository.resolveAdminAccess('user-1');

      expect(access.hasPlatformAccess, isTrue);
      expect(access.canAccessPartnerId('99'), isTrue);
      expect(
        access.activeRoles,
        containsAll(<AdminRole>[AdminRole.admin, AdminRole.partner]),
      );
    });

    test('preserves bank-scoped access from assignment rows', () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'assignment-bank',
            'user_id': 'user-1',
            'role': 'bank',
            'club_id': 'bank-42',
            'assigned_by': 'seed',
            'created_at': '2026-04-14T12:10:00.000Z',
            'is_active': true,
          },
        ],
      );

      final access = await repository.resolveAdminAccess('user-1');

      expect(access.hasBankAdminAccess, isTrue);
      expect(access.canAccessBankId('bank-42'), isTrue);
      expect(access.canAccessPartnerId('bank-42'), isFalse);
      expect(access.activeRoles, contains(AdminRole.bank));
    });

    test('falls back to JWT metadata when the database returns no assignments', () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => const <Map<String, dynamic>>[],
        appMetadataLoader: () => <String, dynamic>{
          'has_partner_access': true,
          'partner_admin_ids': <String>['club-7'],
        },
      );

      final access = await repository.resolveAdminAccess('user-1');

      expect(access.hasPartnerAdminAccess, isTrue);
      expect(access.canAccessPartnerId('club-7'), isTrue);
    });

    test('fails closed when admin assignment loading throws', () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => throw StateError('boom'),
      );

      final access = await repository.resolveAdminAccess('user-1');

      expect(access, same(AdminWorkspaceAccess.none));
    });
  });
}
