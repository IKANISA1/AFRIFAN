part of 'prediction_repository.dart';

extension PredictionRepoProfile on PredictionRepository {
  /// Updates the current user's profile (display_name, club_id, etc.)
  /// for onboarding and privacy settings.
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final releaseSafeUpdates = Map<String, dynamic>.from(updates);
    if (!_storeReleasePolicy.allowsCrossUserText) {
      releaseSafeUpdates
        ..remove('display_name')
        ..remove('nickname')
        ..remove('bio');
      if (releaseSafeUpdates.containsKey('privacy_show_real_name')) {
        releaseSafeUpdates['privacy_show_real_name'] = false;
      }
    }
    if (releaseSafeUpdates.isEmpty) {
      return false;
    }

    final result = await SafeRpc.query<void>(
      () async {
        await _client
            .from('profiles')
            .update(releaseSafeUpdates)
            .eq('id', userId);
      },
      tag: _tag,
      description: 'updateProfile',
      maxAttempts: 2,
    );

    return result.isSuccess;
  }

  /// Returns the current authenticated user ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Whether the current user is authenticated.
  bool get isAuthenticated => _client.auth.currentUser != null;
}
