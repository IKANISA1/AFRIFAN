import 'package:core_network/core_network.dart';
import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/admin_workspace_access.dart';

/// Resolves admin RBAC access for a user.
///
/// Extracted from [AuthRepository] to follow single-responsibility:
/// AuthRepository handles authentication flow, while RbacResolver
/// handles role-based access control resolution.
class RbacResolver {
  RbacResolver({
    required this.tag,
    Future<dynamic> Function(String userId)? adminAssignmentsLoader,
    Map<String, dynamic> Function()? appMetadataLoader,
    SupabaseClient Function()? clientProvider,
  }) : _adminAssignmentsLoader = adminAssignmentsLoader,
       _clientProvider = clientProvider ?? (() => SupabaseClientFactory.client);

  final String tag;
  final Future<dynamic> Function(String userId)? _adminAssignmentsLoader;
  final SupabaseClient Function() _clientProvider;

  /// Columns defined by the governed `admin_role_assignments` schema.
  ///
  /// Keep this explicit so client queries cannot silently drift back to the
  /// retired `assigned_by` / `created_at` names.
  static const String adminAssignmentsProjection =
      'id, user_id, role, club_id, partner_scope_id, granted_by, '
      'granted_at, is_active, revoked_at';

  /// Resolve admin workspace access for a user.
  ///
  /// Returns [AdminWorkspaceAccess.none] if the user has no admin roles,
  /// or if the resolution fails (fail-closed for safety).
  Future<AdminWorkspaceAccess> resolve(String userId) async {
    try {
      final rowsResult = await SafeRpc.query<dynamic>(
        () => _loadAdminAssignments(userId),
        tag: tag,
        description: 'resolveAdminAccess',
        maxAttempts: 3,
      );
      if (!rowsResult.isSuccess) {
        AfriLogger.warn(
          tag,
          'Admin access resolution failed: ${rowsResult.error}',
        );
        return AdminWorkspaceAccess.none;
      }
      return _resolveFromRows(rowsResult.requireData, userId);
    } catch (error, stackTrace) {
      // Non-network error: log and return no access (fail-closed).
      AfriLogger.error(
        tag,
        'Admin access resolution failed.',
        error,
        stackTrace,
      );
      return AdminWorkspaceAccess.none;
    }
  }

  Future<dynamic> _loadAdminAssignments(String userId) {
    final injectedLoader = _adminAssignmentsLoader;
    if (injectedLoader != null) {
      return injectedLoader(userId);
    }

    return _clientProvider()
        .from('admin_role_assignments')
        .select(adminAssignmentsProjection)
        .eq('user_id', userId)
        .eq('is_active', true)
        .isFilter('revoked_at', null);
  }

  AdminWorkspaceAccess _resolveFromRows(dynamic rows, String userId) {
    final assignments = <Map<String, dynamic>>[];
    if (rows is List) {
      for (final raw in rows) {
        final row = raw is Map<String, dynamic>
            ? raw
            : raw is Map
            ? Map<String, dynamic>.from(raw)
            : null;
        if (row == null) {
          continue;
        }
        if (row['user_id'] != userId ||
            row['is_active'] != true ||
            row['revoked_at'] != null) {
          continue;
        }

        final role = AdminRole.fromString(row['role']?.toString());
        if (role == null) {
          AfriLogger.warn(tag, 'Ignoring an unsupported admin role.');
          continue;
        }
        final scopeId = row['partner_scope_id'] ?? row['club_id'];
        assignments.add(<String, dynamic>{
          'id': row['id'],
          'user_id': row['user_id'],
          'role': switch (role) {
            AdminRole.admin => 'admin',
            AdminRole.bank => 'bank',
            AdminRole.partner => 'partner',
          },
          'club_id': row['club_id'],
          'partner_scope_id': scopeId?.toString(),
          'granted_by': row['granted_by'],
          'granted_at': row['granted_at'],
          'is_active': row['is_active'],
          'revoked_at': row['revoked_at'],
        });
      }
    }

    if (assignments.isEmpty) {
      return AdminWorkspaceAccess.none;
    }

    final partnerIds = assignments
        .where((assignment) => assignment['role'] == 'partner')
        .map((assignment) => assignment['partner_scope_id']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final bankIds = assignments
        .where((assignment) => assignment['role'] == 'bank')
        .map((assignment) => assignment['partner_scope_id']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    return AdminWorkspaceAccess.fromRpcResponse(<String, dynamic>{
      'has_platform_access': assignments.any(
        (assignment) => assignment['role'] == 'admin',
      ),
      'has_bank_access': bankIds.isNotEmpty,
      'has_partner_access': false,
      'bank_partner_ids': bankIds.toList(growable: false),
      'partner_admin_ids': partnerIds.toList(growable: false),
      'role_assignments': assignments,
    });
  }
}
