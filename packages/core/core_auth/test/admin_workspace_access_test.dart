import 'package:core_auth/src/models/admin_workspace_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminRole', () {
    test('parses standard role strings', () {
      expect(AdminRole.fromString('admin'), AdminRole.admin);
      expect(AdminRole.fromString('super_admin'), AdminRole.admin);
      expect(AdminRole.fromString('bank'), AdminRole.bank);
      expect(AdminRole.fromString('partner'), AdminRole.partner);
    });

    test('parses legacy club role strings', () {
      expect(AdminRole.fromString('rayon_sport'), AdminRole.partner);
      expect(AdminRole.fromString('rayon-sport'), AdminRole.partner);
      expect(AdminRole.fromString('club_admin'), AdminRole.partner);
      expect(AdminRole.fromString('club_moderator'), AdminRole.partner);
    });

    test('returns null for unknown roles', () {
      expect(AdminRole.fromString('unknown'), isNull);
      expect(AdminRole.fromString('viewer'), isNull);
      expect(AdminRole.fromString(''), isNull);
      expect(AdminRole.fromString(null), isNull);
    });

    test('case insensitive parsing', () {
      expect(AdminRole.fromString('ADMIN'), AdminRole.admin);
      expect(AdminRole.fromString('Partner'), AdminRole.partner);
      expect(AdminRole.fromString('BANK'), AdminRole.bank);
    });

    test('label returns human-readable strings', () {
      expect(AdminRole.admin.label, 'Platform Admin');
      expect(AdminRole.bank.label, 'Bank Admin');
      expect(AdminRole.partner.label, 'Club Admin');
    });

    test('dbValue returns database-friendly strings', () {
      expect(AdminRole.admin.dbValue, 'admin');
      expect(AdminRole.bank.dbValue, 'bank');
      expect(AdminRole.partner.dbValue, 'partner');
    });
  });

  group('AdminRoleAssignment', () {
    test('parses valid JSON', () {
      final json = <String, dynamic>{
        'id': 'assign-1',
        'user_id': 'user-abc',
        'role': 'admin',
        'partner_scope_id': null,
        'partner_name': null,
        'user_name': 'Jean Bosco',
        'user_phone': '+250788000000',
        'granted_by': 'system',
        'granted_at': '2026-01-01T00:00:00Z',
        'revoked_at': null,
        'is_active': true,
        'notes': 'Initial setup',
      };

      final assignment = AdminRoleAssignment.fromJson(json);
      expect(assignment.id, 'assign-1');
      expect(assignment.userId, 'user-abc');
      expect(assignment.role, AdminRole.admin);
      expect(assignment.isActive, isTrue);
      expect(assignment.notes, 'Initial setup');
    });

    test('handles missing fields defensively', () {
      final assignment = AdminRoleAssignment.fromJson(<String, dynamic>{});
      expect(assignment.id, '');
      expect(assignment.userId, '');
      expect(assignment.role, AdminRole.admin); // defaults to admin
      expect(assignment.isActive, isTrue);
    });

    test('parses partner role with scope', () {
      final json = <String, dynamic>{
        'id': 'assign-2',
        'user_id': 'user-xyz',
        'role': 'partner',
        'partner_scope_id': 'club-24',
        'partner_name': 'Rayon Sports',
        'granted_at': '2026-03-15T10:00:00Z',
        'is_active': true,
      };

      final assignment = AdminRoleAssignment.fromJson(json);
      expect(assignment.role, AdminRole.partner);
      expect(assignment.partnerScopeId, 'club-24');
      expect(assignment.partnerName, 'Rayon Sports');
    });

    test('falls back from club_id when partner_scope_id is null', () {
      final json = <String, dynamic>{
        'id': 'assign-3',
        'user_id': 'user-old',
        'role': 'club_admin',
        'club_id': '24',
        'granted_at': '2026-01-01T00:00:00Z',
        'is_active': true,
      };

      final assignment = AdminRoleAssignment.fromJson(json);
      expect(assignment.partnerScopeId, '24');
    });
  });

  group('AdminWorkspaceAccess', () {
    group('none constant', () {
      test('has no access by default', () {
        const access = AdminWorkspaceAccess.none;
        expect(access.hasPlatformAccess, isFalse);
        expect(access.hasBankAccess, isFalse);
        expect(access.hasGlobalPartnerAccess, isFalse);
        expect(access.hasAnyAdminAccess, isFalse);
        expect(access.hasBankAdminAccess, isFalse);
        expect(access.hasPartnerAdminAccess, isFalse);
        expect(access.activeRoles, isEmpty);
      });
    });

    group('platform admin', () {
      test('has access to everything', () {
        const access = AdminWorkspaceAccess(
          hasPlatformAccess: true,
        );

        expect(access.hasAnyAdminAccess, isTrue);
        expect(access.hasBankAdminAccess, isTrue);
        expect(access.hasPartnerAdminAccess, isTrue);
        expect(access.canAccessBankId('bank-1'), isTrue);
        expect(access.canAccessPartnerId('partner-99'), isTrue);
      });
    });

    group('scoped bank admin', () {
      test('can only access explicit bank IDs', () {
        const access = AdminWorkspaceAccess(
          bankAdminIds: <String>{'bank-1', 'bank-2'},
        );

        expect(access.hasBankAdminAccess, isTrue);
        expect(access.canAccessBankId('bank-1'), isTrue);
        expect(access.canAccessBankId('bank-2'), isTrue);
        expect(access.canAccessBankId('bank-3'), isFalse);
        expect(access.hasPartnerAdminAccess, isFalse);
      });
    });

    group('scoped partner admin', () {
      test('can only access explicit partner IDs', () {
        const access = AdminWorkspaceAccess(
          partnerAdminIds: <String>{'24', '42'},
        );

        expect(access.hasPartnerAdminAccess, isTrue);
        expect(access.canAccessPartnerId('24'), isTrue);
        expect(access.canAccessPartnerId('42'), isTrue);
        expect(access.canAccessPartnerId('99'), isFalse);
        expect(access.hasBankAdminAccess, isFalse);
      });
    });

    group('global partner admin', () {
      test('can access all partners', () {
        const access = AdminWorkspaceAccess(
          hasGlobalPartnerAccess: true,
        );

        expect(access.hasPartnerAdminAccess, isTrue);
        expect(access.canAccessPartnerId('any-partner'), isTrue);
      });
    });

    group('edge cases', () {
      test('empty string partner ID returns false', () {
        const access = AdminWorkspaceAccess(hasPlatformAccess: true);
        expect(access.canAccessPartnerId(''), isFalse);
      });

      test('empty string bank ID returns false', () {
        const access = AdminWorkspaceAccess(hasPlatformAccess: true);
        expect(access.canAccessBankId(''), isFalse);
      });

      test('whitespace-only IDs return false', () {
        const access = AdminWorkspaceAccess(hasPlatformAccess: true);
        expect(access.canAccessBankId('   '), isFalse);
        expect(access.canAccessPartnerId('   '), isFalse);
      });
    });

    group('fromRpcResponse', () {
      test('parses full RPC response', () {
        final json = <String, dynamic>{
          'has_platform_access': true,
          'has_bank_access': false,
          'has_partner_access': true,
          'bank_partner_ids': <dynamic>['bank-1'],
          'partner_admin_ids': <dynamic>['24', '42'],
          'role_assignments': <dynamic>[
            <String, dynamic>{
              'id': 'assign-1',
              'user_id': 'user-abc',
              'role': 'admin',
              'granted_at': '2026-01-01T00:00:00Z',
              'is_active': true,
            },
          ],
        };

        final access = AdminWorkspaceAccess.fromRpcResponse(json);
        expect(access.hasPlatformAccess, isTrue);
        expect(access.hasBankAccess, isFalse);
        expect(access.hasGlobalPartnerAccess, isTrue);
        expect(access.bankAdminIds, contains('bank-1'));
        expect(access.partnerAdminIds, containsAll(<String>['24', '42']));
        expect(access.roleAssignments, hasLength(1));
        expect(access.roleAssignments[0].role, AdminRole.admin);
      });

      test('handles empty RPC response', () {
        final access =
            AdminWorkspaceAccess.fromRpcResponse(<String, dynamic>{});
        expect(access.hasPlatformAccess, isFalse);
        expect(access.hasBankAccess, isFalse);
        expect(access.hasAnyAdminAccess, isFalse);
        expect(access.roleAssignments, isEmpty);
      });

      test('handles legacy has_rayon_access field', () {
        final json = <String, dynamic>{
          'has_rayon_access': true,
        };

        final access = AdminWorkspaceAccess.fromRpcResponse(json);
        expect(access.hasGlobalPartnerAccess, isTrue);
      });
    });

    group('fromAppMetadata', () {
      test('parses standard JWT app_metadata', () {
        final metadata = <String, dynamic>{
          'has_platform_access': true,
          'has_bank_access': false,
          'has_partner_access': true,
          'partner_admin_ids': <dynamic>['24'],
        };

        final access = AdminWorkspaceAccess.fromAppMetadata(metadata);
        expect(access.hasPlatformAccess, isTrue);
        expect(access.hasPartnerAdminAccess, isTrue);
        expect(access.partnerAdminIds, contains('24'));
      });

      test('parses legacy admin flag from JWT', () {
        final metadata = <String, dynamic>{
          'is_admin': true,
        };

        final access = AdminWorkspaceAccess.fromAppMetadata(metadata);
        expect(access.hasPlatformAccess, isTrue);
      });

      test('parses bool-like string values', () {
        final metadata = <String, dynamic>{
          'admin': 'true',
          'has_bank_access': '0',
        };

        final access = AdminWorkspaceAccess.fromAppMetadata(metadata);
        expect(access.hasPlatformAccess, isTrue);
        expect(access.hasBankAccess, isFalse);
      });

      test('handles empty metadata', () {
        final access =
            AdminWorkspaceAccess.fromAppMetadata(<String, dynamic>{});
        expect(access.hasAnyAdminAccess, isFalse);
      });
    });
  });
}
