/// Supported admin role types.
///
/// Generalized from cool repo: `admin → platform`, `bank → bank`,
/// `rayonSport → partner` (generic for any club).
enum AdminRole {
  /// Full platform access — can manage everything.
  admin,

  /// Scoped access to bank workspaces.
  bank,

  /// Partner (club) administration — scoped to partner IDs.
  partner;

  static AdminRole? fromString(String? value) {
    if (value == null) return null;
    return switch (value.trim().toLowerCase()) {
      'admin' || 'super_admin' => AdminRole.admin,
      'bank' => AdminRole.bank,
      'partner' ||
      'rayon_sport' ||
      'rayon-sport' ||
      'club_admin' ||
      'club_moderator' => AdminRole.partner,
      _ => null,
    };
  }

  String get label => switch (this) {
    AdminRole.admin => 'Platform Admin',
    AdminRole.bank => 'Bank Admin',
    AdminRole.partner => 'Club Admin',
  };

  String get dbValue => switch (this) {
    AdminRole.admin => 'admin',
    AdminRole.bank => 'bank',
    AdminRole.partner => 'partner',
  };
}

/// A single admin role assignment from the database.
class AdminRoleAssignment {
  const AdminRoleAssignment({
    required this.id,
    required this.userId,
    required this.role,
    this.partnerScopeId,
    this.partnerName,
    this.userName,
    this.userPhone,
    this.grantedBy,
    required this.grantedAt,
    this.revokedAt,
    required this.isActive,
    this.notes,
  });

  final String id;
  final String userId;
  final AdminRole role;
  final String? partnerScopeId;
  final String? partnerName;
  final String? userName;
  final String? userPhone;
  final String? grantedBy;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final bool isActive;
  final String? notes;

  factory AdminRoleAssignment.fromJson(Map<String, dynamic> json) {
    return AdminRoleAssignment(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: AdminRole.fromString(json['role']?.toString()) ?? AdminRole.admin,
      partnerScopeId:
          json['partner_scope_id']?.toString() ?? json['club_id']?.toString(),
      partnerName: json['partner_name']?.toString(),
      userName: json['user_name']?.toString(),
      userPhone: json['user_phone']?.toString(),
      grantedBy: json['granted_by']?.toString(),
      grantedAt:
          DateTime.tryParse(
            json['granted_at']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes']?.toString(),
    );
  }
}

/// Resolved admin workspace access for the current user.
///
/// Determines what admin workspaces this user can access.
class AdminWorkspaceAccess {
  const AdminWorkspaceAccess({
    this.hasPlatformAccess = false,
    this.hasBankAccess = false,
    this.hasGlobalPartnerAccess = false,
    this.bankAdminIds = const <String>{},
    this.partnerAdminIds = const <String>{},
    this.roleAssignments = const <AdminRoleAssignment>[],
  });

  final bool hasPlatformAccess;
  final bool hasBankAccess;
  final bool hasGlobalPartnerAccess;
  final Set<String> bankAdminIds;
  final Set<String> partnerAdminIds;
  final List<AdminRoleAssignment> roleAssignments;

  /// No admin access at all.
  static const none = AdminWorkspaceAccess();

  bool get hasBankAdminAccess =>
      hasPlatformAccess ||
      hasBankAccess ||
      bankAdminIds.isNotEmpty ||
      roleAssignments.any((a) => a.role == AdminRole.bank);

  bool get hasPartnerAdminAccess =>
      hasPlatformAccess ||
      hasGlobalPartnerAccess ||
      partnerAdminIds.isNotEmpty ||
      roleAssignments.any((a) => a.role == AdminRole.partner);

  bool get hasAnyAdminAccess =>
      hasPlatformAccess || hasBankAdminAccess || hasPartnerAdminAccess;

  Set<AdminRole> get activeRoles => roleAssignments.map((a) => a.role).toSet();

  bool canAccessBankId(String bankId) {
    final normalized = bankId.trim();
    if (normalized.isEmpty) return false;
    if (hasPlatformAccess) return true;
    return bankAdminIds.contains(normalized);
  }

  bool canAccessPartnerId(String partnerId) {
    final normalized = partnerId.trim();
    if (normalized.isEmpty) return false;
    if (hasPlatformAccess || hasGlobalPartnerAccess) return true;
    return partnerAdminIds.contains(normalized);
  }

  /// Parse the RPC response from `get_admin_access_for_user`.
  factory AdminWorkspaceAccess.fromRpcResponse(Map<String, dynamic> json) {
    final rawAssignments = json['role_assignments'];
    final assignments = <AdminRoleAssignment>[];
    if (rawAssignments is List) {
      for (final raw in rawAssignments) {
        if (raw is Map<String, dynamic>) {
          assignments.add(AdminRoleAssignment.fromJson(raw));
        } else if (raw is Map) {
          assignments.add(AdminRoleAssignment.fromJson(raw.cast()));
        }
      }
    }

    return AdminWorkspaceAccess(
      hasPlatformAccess: json['has_platform_access'] as bool? ?? false,
      hasBankAccess: json['has_bank_access'] as bool? ?? false,
      hasGlobalPartnerAccess:
          json['has_partner_access'] as bool? ??
          json['has_rayon_access'] as bool? ??
          false,
      bankAdminIds: _stringSet(json['bank_partner_ids']),
      partnerAdminIds: _stringSet(json['partner_admin_ids']),
      roleAssignments: assignments,
    );
  }

  /// Fallback: parse from Supabase app_metadata in the JWT.
  factory AdminWorkspaceAccess.fromAppMetadata(Map<String, dynamic> metadata) {
    return AdminWorkspaceAccess(
      hasPlatformAccess: _boolValue(
        metadata['has_platform_access'] ??
            metadata['is_admin'] ??
            metadata['admin'],
      ),
      hasBankAccess: _boolValue(metadata['has_bank_access']),
      hasGlobalPartnerAccess: _boolValue(
        metadata['has_partner_access'] ?? metadata['has_rayon_access'],
      ),
      bankAdminIds: _stringSet(
        metadata['bank_partner_ids'] ?? metadata['bank_admin_ids'],
      ),
      partnerAdminIds: _stringSet(metadata['partner_admin_ids']),
    );
  }

  static bool _boolValue(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      return switch (raw.trim().toLowerCase()) {
        'true' || '1' || 'yes' => true,
        _ => false,
      };
    }
    return false;
  }

  static Set<String> _stringSet(dynamic raw) {
    if (raw is! List) return const <String>{};
    return raw
        .map((v) => v?.toString().trim() ?? '')
        .where((v) => v.isNotEmpty)
        .toSet();
  }
}
