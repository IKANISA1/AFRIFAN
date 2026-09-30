import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'ports.dart';

/// A dedicated native HTTP client, normal platform TLS trust and no cookie jar.
/// A single write is never retried; redirects and compressed bodies are refused.
final class IoNativeIdentityTransport implements NativeIdentityTransport {
  const IoNativeIdentityTransport();
  @override
  Future<NativeIdentityResponse> send(
    NativeIdentityRequest request,
    Duration timeout,
  ) async {
    identityRequire(
      request.uri.scheme == 'https' &&
          request.uri.userInfo.isEmpty &&
          !request.uri.hasQuery &&
          !request.uri.hasFragment &&
          ['GET', 'POST'].contains(request.method) &&
          timeout.inMilliseconds > 0 &&
          timeout.inMilliseconds <= 30000,
      NativeIdentityError.invalidConfiguration,
    );
    final allowedHeaders = {
      'x-africlub-client',
      'accept',
      'content-type',
      'idempotency-key',
      'authorization',
    };
    identityRequire(
      request.headers.keys.every(allowedHeaders.contains) &&
          request.headers['x-africlub-client'] == 'native-v1' &&
          request.headers.values.every(
            (v) => !v.contains('\r') && !v.contains('\n'),
          ),
      NativeIdentityError.invalidInput,
    );
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..autoUncompress = false;
    HttpClientRequest? active;
    var stopped = false;
    Future<NativeIdentityResponse> run() async {
      final outgoing = await client.openUrl(request.method, request.uri);
      active = outgoing;
      if (stopped) {
        outgoing.abort();
        throw const NativeIdentityFailure(NativeIdentityError.responseDeadline);
      }
      outgoing.followRedirects = false;
      outgoing.maxRedirects = 0;
      outgoing.persistentConnection = false;
      outgoing.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.forEach(outgoing.headers.set);
      if (request.body != null) {
        final bytes = utf8.encode(request.body!);
        identityRequire(bytes.length <= 4096, NativeIdentityError.invalidInput);
        outgoing.add(bytes);
      }
      final response = await outgoing.close();
      identityRequire(
        response.contentLength <= 16384,
        NativeIdentityError.responseTooLarge,
      );
      final encoding = response.headers.value(
        HttpHeaders.contentEncodingHeader,
      );
      identityRequire(encoding == null || encoding == 'identity');
      final bytes = <int>[];
      await for (final chunk in response) {
        identityRequire(
          bytes.length + chunk.length <= 16384,
          NativeIdentityError.responseTooLarge,
        );
        bytes.addAll(chunk);
      }
      final headers = <String, String>{};
      response.headers.forEach(
        (key, values) => headers[key.toLowerCase()] = values.join(','),
      );
      return NativeIdentityResponse(
        response.statusCode,
        headers,
        utf8.decode(bytes, allowMalformed: false),
      );
    }

    try {
      return await run().timeout(timeout);
    } finally {
      stopped = true;
      active?.abort();
      client.close(force: true);
    }
  }
}
