import 'package:equatable/equatable.dart';

/// Generalized user profile for multi-tenant club apps.
///
/// Stripped of client-side fake fields to match the DB exactly.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.clubId,
    String? momoNumber,
    String? phone,
    String? displayName,
    String? fullName,
    this.publicUserId,
    String? country,
    String? countryCode,
    this.languageCode,
    this.avatarUrl,
    this.momoProvider,
    this.isActive = true,
    this.isAdmin = false,
  }) : momoNumber = momoNumber ?? phone,
       displayName = displayName ?? fullName,
       countryCode = countryCode ?? country;

  final String id;
  final String clubId;
  final String? momoNumber;
  final String? displayName;
  final String? publicUserId;
  final String? countryCode;
  final String? languageCode;
  final String? avatarUrl;
  final String? momoProvider;
  final bool isActive;
  final bool isAdmin;

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

  /// Legacy alias kept for compatibility with older feature code.
  String? get phone => momoNumber;

  /// Legacy alias kept for compatibility with older feature code.
  String? get fullName => displayName;

  /// Legacy alias kept for compatibility with older feature code.
  String? get country => countryCode;

  // ─── Serialization ──────────────────────────────────────────

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _asString(json['id']),
      clubId: _asString(json['club_id']),
      momoNumber: _asNullableString(json['momo_number'] ?? json['phone']),
      displayName: _asNullableString(json['display_name'] ?? json['full_name']),
      publicUserId: _asNullableString(json['public_user_id']),
      countryCode: _asNullableString(json['country_code'] ?? json['country']),
      languageCode: _asNullableString(json['language_code']),
      avatarUrl: _asNullableString(json['avatar_url']),
      momoProvider: _asNullableString(json['momo_provider']),
      isActive: _asBool(json['is_active'], fallback: true),
      isAdmin: _asBool(json['is_admin'], fallback: false),
    );
  }

  /// Serialize to the canonical `profiles` row contract in Supabase.
  Map<String, dynamic> toProfileRow({bool includeId = true}) {
    final normalizedClubId = int.tryParse(clubId);
    final normalizedDisplayName = _trimToNull(displayName);
    final normalizedAlias = _trimToNull(publicUserId);
    final normalizedCountry = _trimToNull(countryCode);
    final normalizedLanguage = _trimToNull(languageCode) ?? 'en';
    final normalizedAvatar = _trimToNull(avatarUrl);

    return <String, dynamic>{
      if (includeId) 'id': id,
      if (normalizedClubId != null) 'club_id': normalizedClubId,
      if (normalizedAlias != null) 'public_user_id': normalizedAlias,
      'display_name': normalizedDisplayName,
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
    String? phone,
    String? displayName,
    String? fullName,
    String? publicUserId,
    String? country,
    String? countryCode,
    String? languageCode,
    String? avatarUrl,
    String? momoProvider,
    bool? isActive,
    bool? isAdmin,
  }) {
    return UserProfile(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      momoNumber: momoNumber ?? phone ?? this.momoNumber,
      displayName: displayName ?? fullName ?? this.displayName,
      publicUserId: publicUserId ?? this.publicUserId,
      countryCode: countryCode ?? country ?? this.countryCode,
      languageCode: languageCode ?? this.languageCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      momoProvider: momoProvider ?? this.momoProvider,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
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
    countryCode,
    languageCode,
    avatarUrl,
    momoProvider,
    isActive,
    isAdmin,
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
