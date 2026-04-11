class FantasyException implements Exception {
  const FantasyException(this.message, {this.code});

  final String message;
  final String? code;

  factory FantasyException.auth(String message) {
    return FantasyException(message, code: 'auth');
  }

  factory FantasyException.data(String message) {
    return FantasyException(message, code: 'data');
  }

  factory FantasyException.validation(String message) {
    return FantasyException(message, code: 'validation');
  }

  factory FantasyException.offline([String message = 'Offline mode']) {
    return FantasyException(message, code: 'offline');
  }

  @override
  String toString() => 'FantasyException($code): $message';
}
