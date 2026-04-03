class BiopayLivenessChallenge {
  const BiopayLivenessChallenge({
    required this.token,
    required this.mode,
    required this.expiresAt,
  });

  factory BiopayLivenessChallenge.fromApiResponse(Map<String, dynamic> data) {
    return BiopayLivenessChallenge(
      token: data['token']?.toString() ?? '',
      mode: data['mode']?.toString() ?? 'payment',
      expiresAt:
          DateTime.tryParse(data['expires_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String token;
  final String mode;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
