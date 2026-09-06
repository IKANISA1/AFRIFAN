import 'package:equatable/equatable.dart';

/// Generalized user profile for multi-tenant club apps.
///
/// Stripped of client-side fake fields to match the DB exactly.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.clubId,
    this.momoNumber,
    this.displayName,
    this.publicUserId,
    this.favoriteTeamSlug,
    this.countryCode,
    this.languageCode,
    this.avatarUrl,
    this.momoProvider,
    this.isActive = true,
    this.isAdmin = false,
    this.updatedAt,
  });

  final String id;
  final String clubId;
  final String? momoNumber;
  final String? displayName;
  final String? publicUserId;
  final String? favoriteTeamSlug;
  final String? countryCode;
  final String? languageCode;
  final String? avatarUrl;
  final String? momoProvider;
  final bool isActive;
  final bool isAdmin;
  final String? updatedAt;

  // ─── Derived helpers ──────────────────────────────────────────

  /// Whether the profile has a stable supporter-facing identity.
  ///
  /// Mobile money is optional at the account level, so completeness should
  /// depend on alias or display information rather than a saved payment route.
  bool get isProfileComplete {
    final alias = publicUserId?.trim();
    if (alias != null && alias.isNotEmpty) {
      return true;
    }
    final name = displayName?.trim();
    return name != null && name.isNotEmpty;
  }

  /// Whether the user has MoMo configured.
  bool get hasMomo => momoNumber != null && momoNumber!.trim().isNotEmpty;

  // ─── Serialization ──────────────────────────────────────────

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _asString(json['id']),
      clubId: _asString(json['club_id']),
      momoNumber: _asNullableString(json['momo_number'] ?? json['phone']),
      displayName: _asNullableString(json['display_name'] ?? json['full_name']),
      publicUserId: _asNullableString(json['public_user_id']),
      favoriteTeamSlug: _asNullableString(json['favorite_team_slug']),
      countryCode: _asNullableString(json['country_code'] ?? json['country']),
      languageCode: 'en',
      avatarUrl: _asNullableString(json['avatar_url']),
      momoProvider: _asNullableString(json['momo_provider']),
      isActive: _asBool(json['is_active'], fallback: true),
      isAdmin: _asBool(json['is_admin'], fallback: false),
      updatedAt: _asNullableString(json['updated_at']),
    );
  }

  /// Serialize to the canonical `profiles` row contract in Supabase.
  Map<String, dynamic> toProfileRow({bool includeId = true}) {
    final normalizedClubId = int.tryParse(clubId);
    final normalizedDisplayName = _trimToNull(displayName);
    final normalizedAlias = _trimToNull(publicUserId);
    final normalizedFavoriteTeam = _trimToNull(favoriteTeamSlug);
    final normalizedCountry = _trimToNull(countryCode);
    const normalizedLanguage = 'en';
    final normalizedAvatar = _trimToNull(avatarUrl);

    return <String, dynamic>{
      if (includeId) 'id': id,
      if (normalizedClubId != null) 'club_id': normalizedClubId,
      if (normalizedAlias != null) 'public_user_id': normalizedAlias,
      'display_name': normalizedDisplayName,
      'favorite_team_slug': normalizedFavoriteTeam,
      'country_code': normalizedCountry,
      'language_code': normalizedLanguage,
      'avatar_url': normalizedAvatar,
      'is_active': isActive,
    };
  }

  /// Serialize to the canonical `user_private_contacts` row contract.
  Map<String, dynamic> toPrivateContactRow({bool includeId = true}) {
    final normalizedClubId = int.tryParse(clubId);
    final normalizedMomo = _trimToNull(momoNumber);
    final normalizedCountry = _trimToNull(countryCode);
    final normalizedProvider = _trimToNull(momoProvider);

    return <String, dynamic>{
      if (includeId) 'user_id': id,
      if (normalizedClubId != null) 'club_id': normalizedClubId,
      'momo_number': normalizedMomo,
      'whatsapp_number': normalizedMomo,
      'momo_provider': normalizedProvider,
      'country_code': normalizedCountry,
    };
  }

  Map<String, dynamic> toJson() => toProfileRow();

  UserProfile copyWith({
    String? id,
    String? clubId,
    String? momoNumber,
    String? displayName,
    String? publicUserId,
    String? favoriteTeamSlug,
    String? countryCode,
    String? languageCode,
    String? avatarUrl,
    String? momoProvider,
    bool? isActive,
    bool? isAdmin,
    String? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      momoNumber: momoNumber ?? this.momoNumber,
      displayName: displayName ?? this.displayName,
      publicUserId: publicUserId ?? this.publicUserId,
      favoriteTeamSlug: favoriteTeamSlug ?? this.favoriteTeamSlug,
      countryCode: countryCode ?? this.countryCode,
      languageCode: languageCode ?? this.languageCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      momoProvider: momoProvider ?? this.momoProvider,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Empty profile for a guest user.
  factory UserProfile.guest({required String clubId}) =>
      UserProfile(id: '', clubId: clubId, isActive: true);

  @override
  List<Object?> get props => [
    id,
    clubId,
    momoNumber,
    displayName,
    publicUserId,
    favoriteTeamSlug,
    countryCode,
    languageCode,
    avatarUrl,
    momoProvider,
    isActive,
    isAdmin,
    updatedAt,
  ];
}

// ─── Safe parsing helpers ───────────────────────────────────────

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final s = value.toString().trim();
  return s.isEmpty ? fallback : s;
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

String? _trimToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.toLowerCase().trim()) {
      'true' || '1' || 'yes' => true,
      _ => fallback,
    };
  }
  return fallback;
}
