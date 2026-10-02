import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository.resolveAdminAccess', () {
    test(
      'normalizes platform and partner assignments from the database',
      () async {
        final repository = AuthRepository(
          clubId: '24',
          adminAssignmentsLoader: (_) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'assignment-1',
              'user_id': 'user-1',
              'role': 'super_admin',
              'club_id': 24,
              'granted_by': 'seed',
              'granted_at': '2026-04-14T12:00:00.000Z',
              'is_active': true,
            },
            <String, dynamic>{
              'id': 'assignment-2',
              'user_id': 'user-1',
              'role': 'club_admin',
              'club_id': 99,
              'granted_by': 'seed',
              'granted_at': '2026-04-14T12:05:00.000Z',
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
      },
    );

    test('preserves bank-scoped access from assignment rows', () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'assignment-bank',
            'user_id': 'user-1',
            'role': 'bank',
            'partner_scope_id': 'bank-42',
            'granted_by': 'seed',
            'granted_at': '2026-04-14T12:10:00.000Z',
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

    test('uses the governed role-assignment projection', () {
      expect(
        RbacResolver.adminAssignmentsProjection,
        'id, user_id, role, club_id, partner_scope_id, granted_by, '
        'granted_at, is_active, revoked_at',
      );
      expect(
        RbacResolver.adminAssignmentsProjection,
        isNot(contains('assigned_by')),
      );
      expect(
        RbacResolver.adminAssignmentsProjection,
        isNot(contains('created_at')),
      );
    });

    test('prefers partner scope and preserves governed audit fields', () async {
      final repository = AuthRepository(
        clubId: '24',
        adminAssignmentsLoader: (_) async => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'assignment-partner',
            'user_id': 'user-1',
            'role': 'partner',
            'club_id': 24,
            'partner_scope_id': 'partner-7',
            'granted_by': 'admin-1',
            'granted_at': '2026-04-14T12:15:00.000Z',
            'is_active': true,
          },
        ],
      );

      final access = await repository.resolveAdminAccess('user-1');

      expect(access.canAccessPartnerId('partner-7'), isTrue);
      expect(access.canAccessPartnerId('24'), isFalse);
      expect(access.roleAssignments.single.grantedBy, 'admin-1');
      expect(
        access.roleAssignments.single.grantedAt,
        DateTime.parse('2026-04-14T12:15:00.000Z'),
      );
    });

    test(
      'ignores unsupported database roles instead of granting access',
      () async {
        final repository = AuthRepository(
          clubId: '24',
          adminAssignmentsLoader: (_) async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'assignment-unknown',
              'user_id': 'user-1',
              'role': 'future_unapproved_role',
              'partner_scope_id': 'partner-7',
              'granted_by': 'admin-1',
              'granted_at': '2026-04-14T12:20:00.000Z',
              'is_active': true,
            },
          ],
          appMetadataLoader: () => const <String, dynamic>{},
        );

        final access = await repository.resolveAdminAccess('user-1');

        expect(access.hasAnyAdminAccess, isFalse);
        expect(access.roleAssignments, isEmpty);
      },
    );

    test(
      'empty authoritative assignments never regain access from JWT metadata',
      () async {
        final repository = AuthRepository(
          clubId: '24',
          adminAssignmentsLoader: (_) async => const <Map<String, dynamic>>[],
          appMetadataLoader: () => <String, dynamic>{
            'has_partner_access': true,
            'partner_admin_ids': <String>['club-7'],
          },
        );

        final access = await repository.resolveAdminAccess('user-1');

        expect(access.hasAnyAdminAccess, isFalse);
        expect(access.canAccessPartnerId('club-7'), isFalse);
      },
    );

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
