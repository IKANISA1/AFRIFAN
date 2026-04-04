import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for core_auth models — UserProfile, AdminWorkspaceAccess,
/// AdminRole, AdminRoleAssignment, AuthState, and UserSession.
void main() {
  // ═══════════════════════════════════════════════════════════
  // UserProfile
  // ═══════════════════════════════════════════════════════════

  group('UserProfile', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final profile = UserProfile.fromJson({
          'id': 'user-1',
          'club_id': '42',
          'momo_number': '+250788123456',
          'display_name': 'Jean',
          'public_user_id': '123-456',
          'country_code': 'RW',
          'language_code': 'rw',
          'avatar_url': 'https://example.com/avatar.jpg',
          'momo_provider': 'MTN',
          'is_active': true,
          'is_admin': false,
        });

        expect(profile.id, 'user-1');
        expect(profile.clubId, '42');
        expect(profile.momoNumber, '+250788123456');
        expect(profile.displayName, 'Jean');
        expect(profile.publicUserId, '123-456');
        expect(profile.countryCode, 'RW');
        expect(profile.languageCode, 'rw');
        expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
        expect(profile.momoProvider, 'MTN');
        expect(profile.isActive, isTrue);
        expect(profile.isAdmin, isFalse);
      });

      test('handles legacy field aliases (phone, full_name, country)', () {
        final profile = UserProfile.fromJson({
          'id': 'user-2',
          'club_id': '1',
          'phone': '+250788000000',
          'full_name': 'Legacy User',
          'country': 'MT',
        });

        expect(profile.momoNumber, '+250788000000');
        expect(profile.displayName, 'Legacy User');
        expect(profile.countryCode, 'MT');
        // Verify legacy getters
        expect(profile.phone, profile.momoNumber);
        expect(profile.fullName, profile.displayName);
        expect(profile.country, profile.countryCode);
      });

      test('handles minimal/null fields gracefully', () {
        final profile = UserProfile.fromJson({
          'id': 'user-3',
          'club_id': '1',
        });

        expect(profile.id, 'user-3');
        expect(profile.momoNumber, isNull);
        expect(profile.displayName, isNull);
        expect(profile.isActive, isTrue);
        expect(profile.isAdmin, isFalse);
      });

      test('handles bool-as-string and bool-as-number for is_active', () {
        final fromString = UserProfile.fromJson({
          'id': 'u1',
          'club_id': '1',
          'is_active': 'true',
        });
        expect(fromString.isActive, isTrue);

        final fromNum = UserProfile.fromJson({
          'id': 'u2',
          'club_id': '1',
          'is_active': 1,
        });
        expect(fromNum.isActive, isTrue);

        final fromZero = UserProfile.fromJson({
          'id': 'u3',
          'club_id': '1',
          'is_active': 0,
        });
        expect(fromZero.isActive, isFalse);
      });
    });

    group('derived helpers', () {
      test('isProfileComplete requires non-empty momoNumber', () {
        const complete = UserProfile(
          id: 'u1',
          clubId: '1',
          momoNumber: '+250788111111',
        );
        expect(complete.isProfileComplete, isTrue);
        expect(complete.hasMomo, isTrue);

        const incomplete = UserProfile(id: 'u2', clubId: '1');
        expect(incomplete.isProfileComplete, isFalse);
        expect(incomplete.hasMomo, isFalse);

        const empty = UserProfile(id: 'u3', clubId: '1', momoNumber: '  ');
        expect(empty.isProfileComplete, isFalse);
      });
    });

    group('toProfileRow', () {
      test('includes id when includeId is true', () {
        const profile = UserProfile(
          id: 'user-1',
          clubId: '42',
          displayName: 'Jean',
        );
        final row = profile.toProfileRow(includeId: true);
        expect(row['id'], 'user-1');
        expect(row['club_id'], 42); // Should be int
        expect(row['display_name'], 'Jean');
      });

      test('excludes id when includeId is false', () {
        const profile = UserProfile(id: 'user-1', clubId: '42');
        final row = profile.toProfileRow(includeId: false);
        expect(row.containsKey('id'), isFalse);
      });

      test('normalizes club_id to int', () {
        const profile = UserProfile(id: 'u', clubId: '42');
        expect(profile.toProfileRow()['club_id'], 42);
      });

      test('handles non-numeric club_id gracefully', () {
        const profile = UserProfile(id: 'u', clubId: 'not-a-number');
        final row = profile.toProfileRow();
        expect(row.containsKey('club_id'), isFalse);
      });

      test('trims whitespace-only fields to null', () {
        const profile = UserProfile(
          id: 'u',
          clubId: '1',
          displayName: '  ',
          avatarUrl: '  ',
        );
        final row = profile.toProfileRow();
        expect(row['display_name'], isNull);
        expect(row['avatar_url'], isNull);
      });
    });

    group('toPrivateContactRow', () {
      test('includes user_id when includeId is true', () {
        const profile = UserProfile(
          id: 'user-1',
          clubId: '42',
          momoNumber: '+250788123456',
          momoProvider: 'MTN',
        );
        final row = profile.toPrivateContactRow(includeId: true);
        expect(row['user_id'], 'user-1');
        expect(row['momo_number'], '+250788123456');
        expect(row['whatsapp_number'], '+250788123456');
        expect(row['momo_provider'], 'MTN');
      });
    });

    group('copyWith', () {
      test('overrides specified fields', () {
        const original = UserProfile(
          id: 'u1',
          clubId: '1',
          displayName: 'Jean',
          momoNumber: '+250788111111',
        );
        final updated = original.copyWith(
          displayName: 'Updated Name',
          isAdmin: true,
        );

        expect(updated.displayName, 'Updated Name');
        expect(updated.isAdmin, isTrue);
        expect(updated.momoNumber, '+250788111111'); // unchanged
        expect(updated.id, 'u1'); // unchanged
      });
    });

    group('guest', () {
      test('creates guest with empty id and isActive true', () {
        final guest = UserProfile.guest(clubId: '42');
        expect(guest.id, '');
        expect(guest.clubId, '42');
        expect(guest.isActive, isTrue);
        expect(guest.isProfileComplete, isFalse);
      });
    });

    group('equatable', () {
      test('two profiles with same props are equal', () {
        const a = UserProfile(id: 'u', clubId: '1', displayName: 'Jean');
        const b = UserProfile(id: 'u', clubId: '1', displayName: 'Jean');
        expect(a, equals(b));
      });

      test('profiles with different ids are not equal', () {
        const a = UserProfile(id: 'u1', clubId: '1');
        const b = UserProfile(id: 'u2', clubId: '1');
        expect(a, isNot(equals(b)));
      });
    });
  });

  // ═══════════════════════════════════════════════════════════
  // AdminRole
  // ═══════════════════════════════════════════════════════════

  group('AdminRole', () {
    test('fromString parses known roles', () {
      expect(AdminRole.fromString('admin'), AdminRole.admin);
      expect(AdminRole.fromString('super_admin'), AdminRole.admin);
      expect(AdminRole.fromString('bank'), AdminRole.bank);
      expect(AdminRole.fromString('partner'), AdminRole.partner);
      expect(AdminRole.fromString('rayon_sport'), AdminRole.partner);
      expect(AdminRole.fromString('rayon-sport'), AdminRole.partner);
      expect(AdminRole.fromString('club_admin'), AdminRole.partner);
      expect(AdminRole.fromString('club_moderator'), AdminRole.partner);
    });

    test('fromString is case-insensitive', () {
      expect(AdminRole.fromString('ADMIN'), AdminRole.admin);
      expect(AdminRole.fromString('  Bank  '), AdminRole.bank);
    });

    test('fromString returns null for unknown roles', () {
      expect(AdminRole.fromString('viewer'), isNull);
      expect(AdminRole.fromString(''), isNull);
      expect(AdminRole.fromString(null), isNull);
    });

    test('label provides human-readable names', () {
      expect(AdminRole.admin.label, 'Platform Admin');
      expect(AdminRole.bank.label, 'Bank Admin');
      expect(AdminRole.partner.label, 'Club Admin');
    });

    test('dbValue provides database values', () {
      expect(AdminRole.admin.dbValue, 'admin');
      expect(AdminRole.bank.dbValue, 'bank');
      expect(AdminRole.partner.dbValue, 'partner');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // AdminRoleAssignment
  // ═══════════════════════════════════════════════════════════

  group('AdminRoleAssignment', () {
    test('fromJson parses all fields', () {
      final assignment = AdminRoleAssignment.fromJson({
        'id': 'assign-1',
        'user_id': 'user-1',
        'role': 'partner',
        'partner_scope_id': '42',
        'partner_name': 'Rayon Sports',
        'user_name': 'Jean',
        'user_phone': '+250788111111',
        'granted_by': 'admin-1',
        'created_at': '2026-01-01T00:00:00Z',
        'is_active': true,
      });

      expect(assignment.id, 'assign-1');
      expect(assignment.userId, 'user-1');
      expect(assignment.role, AdminRole.partner);
      expect(assignment.partnerScopeId, '42');
      expect(assignment.partnerName, 'Rayon Sports');
      expect(assignment.isActive, isTrue);
    });

    test('fromJson falls back to club_id for partner_scope_id', () {
      final assignment = AdminRoleAssignment.fromJson({
        'id': '1',
        'user_id': 'u',
        'role': 'partner',
        'club_id': '99',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(assignment.partnerScopeId, '99');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // AdminWorkspaceAccess
  // ═══════════════════════════════════════════════════════════

  group('AdminWorkspaceAccess', () {
    test('none has no access', () {
      const access = AdminWorkspaceAccess.none;
      expect(access.hasPlatformAccess, isFalse);
      expect(access.hasBankAdminAccess, isFalse);
      expect(access.hasPartnerAdminAccess, isFalse);
      expect(access.hasAnyAdminAccess, isFalse);
    });

    test('platform admin can access everything', () {
      const access = AdminWorkspaceAccess(hasPlatformAccess: true);
      expect(access.hasAnyAdminAccess, isTrue);
      expect(access.hasBankAdminAccess, isTrue);
      expect(access.hasPartnerAdminAccess, isTrue);
      expect(access.canAccessBankId('any-bank'), isTrue);
      expect(access.canAccessPartnerId('any-partner'), isTrue);
    });

    test('canAccessBankId requires matching bankId', () {
      const access = AdminWorkspaceAccess(
        bankAdminIds: {'bank-1', 'bank-2'},
      );
      expect(access.canAccessBankId('bank-1'), isTrue);
      expect(access.canAccessBankId('bank-3'), isFalse);
      expect(access.canAccessBankId(''), isFalse);
      expect(access.canAccessBankId('  '), isFalse);
    });

    test('canAccessPartnerId respects global partner access', () {
      const access = AdminWorkspaceAccess(hasGlobalPartnerAccess: true);
      expect(access.canAccessPartnerId('any-id'), isTrue);
    });

    group('fromRpcResponse', () {
      test('parses platform admin response', () {
        final access = AdminWorkspaceAccess.fromRpcResponse({
          'has_platform_access': true,
          'has_bank_access': false,
          'has_partner_access': false,
          'partner_admin_ids': <String>[],
          'role_assignments': [
            {
              'id': '1',
              'user_id': 'u1',
              'role': 'admin',
              'created_at': '2026-01-01T00:00:00Z',
              'is_active': true,
            },
          ],
        });

        expect(access.hasPlatformAccess, isTrue);
        expect(access.roleAssignments, hasLength(1));
        expect(access.roleAssignments.first.role, AdminRole.admin);
      });

      test('parses partner admin response', () {
        final access = AdminWorkspaceAccess.fromRpcResponse({
          'has_platform_access': false,
          'has_bank_access': false,
          'has_partner_access': false,
          'partner_admin_ids': ['42', '99'],
          'role_assignments': [],
        });

        expect(access.partnerAdminIds, containsAll(['42', '99']));
        expect(access.hasPartnerAdminAccess, isTrue);
      });
    });

    group('fromAppMetadata', () {
      test('parses admin flag from JWT metadata', () {
        final access = AdminWorkspaceAccess.fromAppMetadata({
          'is_admin': true,
        });
        expect(access.hasPlatformAccess, isTrue);
      });

      test('parses legacy admin key', () {
        final access = AdminWorkspaceAccess.fromAppMetadata({
          'admin': true,
        });
        expect(access.hasPlatformAccess, isTrue);
      });

      test('handles legacy rayon_access key', () {
        final access = AdminWorkspaceAccess.fromAppMetadata({
          'has_rayon_access': true,
        });
        expect(access.hasGlobalPartnerAccess, isTrue);
      });

      test('returns no access for empty metadata', () {
        final access = AdminWorkspaceAccess.fromAppMetadata({});
        expect(access.hasAnyAdminAccess, isFalse);
      });
    });
  });

  // ═══════════════════════════════════════════════════════════
  // AuthState
  // ═══════════════════════════════════════════════════════════

  group('AuthState', () {
    test('AuthInitial defaults', () {
      const state = AuthInitial();
      expect(state.user, isNull);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.adminAccess, AdminWorkspaceAccess.none);
    });

    test('AuthLoading isLoading is true', () {
      const state = AuthLoading();
      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('AuthAuthenticated exposes profile and workspace', () {
      const profile = UserProfile(id: 'u1', clubId: '1');
      const workspace = AdminWorkspaceAccess(hasPlatformAccess: true);
      const state = AuthAuthenticated(
        profile: profile,
        workspace: workspace,
      );

      expect(state.user, profile);
      expect(state.isAuthenticated, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.adminAccess.hasPlatformAccess, isTrue);
    });

    test('AuthUnauthenticated defaults', () {
      const state = AuthUnauthenticated();
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
    });

    test('AuthError holds message and error', () {
      final error = Exception('test');
      final state = AuthError('Something failed', error);
      expect(state.message, 'Something failed');
      expect(state.error, error);
      expect(state.isAuthenticated, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // UserSession
  // ═══════════════════════════════════════════════════════════

  group('UserSession', () {
    test('guest constructor has expected defaults', () {
      const session = UserSession.guest(clubId: '42');
      expect(session.userId, '');
      expect(session.clubId, '42');
      expect(session.alias, '000-000');
      expect(session.xpTotal, 0);
      expect(session.tier, 'bronze');
      expect(session.isAuthenticated, isFalse);
    });

    test('copyWith overrides specified fields', () {
      const session = UserSession(
        userId: 'u1',
        clubId: '42',
        alias: '123-456',
      );
      final updated = session.copyWith(
        xpTotal: 500,
        tier: 'gold',
        isAuthenticated: true,
      );

      expect(updated.userId, 'u1'); // unchanged
      expect(updated.xpTotal, 500);
      expect(updated.tier, 'gold');
      expect(updated.isAuthenticated, isTrue);
    });
  });
}
