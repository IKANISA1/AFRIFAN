import 'dart:async';

import 'package:http/http.dart' as http;

/// Thin transport wrapper that enforces a default timeout on every request.
///
/// Supabase uses the injected [http.Client] for auth, PostgREST, functions,
/// and storage calls, so enforcing the timeout here hardens the whole stack.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, {this.timeout = const Duration(seconds: 15)});

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner
        .send(request)
        .timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'HTTP request to ${request.url} timed out after '
            '${timeout.inSeconds}s.',
          ),
        );
  }

  @override
  void close() {
    _inner.close();
  }
}
