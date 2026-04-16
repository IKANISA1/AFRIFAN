class BioPayLivenessChallenge {
  const BioPayLivenessChallenge({
    required this.token,
    required this.mode,
    required this.expiresAt,
  });

  factory BioPayLivenessChallenge.fromApiResponse(Map<String, dynamic> data) {
    return BioPayLivenessChallenge(
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
