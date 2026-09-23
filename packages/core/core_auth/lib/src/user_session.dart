/// Represents the current user session.
///
/// "Anonymous Identity" — users are identified by 6-digit numeric .
class UserSession {
  final String userId;
  final String clubId;
  final String alias;
  final int xpTotal;
  final String tier;
  final bool isAuthenticated;

  const UserSession({
    required this.userId,
    required this.clubId,
    required this.alias,
    this.xpTotal = 0,
    this.tier = 'bronze',
    this.isAuthenticated = false,
  });

  const UserSession.guest({required this.clubId})
    : userId = '',
      alias = '000-000',
      xpTotal = 0,
      tier = 'bronze',
      isAuthenticated = false;

  UserSession copyWith({
    String? userId,
    String? clubId,
    String? alias,
    int? xpTotal,
    String? tier,
    bool? isAuthenticated,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      clubId: clubId ?? this.clubId,
      alias: alias ?? this.alias,
      xpTotal: xpTotal ?? this.xpTotal,
      tier: tier ?? this.tier,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
