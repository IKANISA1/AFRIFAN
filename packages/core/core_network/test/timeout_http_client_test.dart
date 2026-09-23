import 'dart:async';

import 'package:core_network/src/timeout_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('throws TimeoutException when inner client stalls', () async {
    final client = TimeoutHttpClient(
      _FakeClient(
        onSend: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
        },
      ),
      timeout: const Duration(milliseconds: 5),
    );

    expect(
      () => client.send(http.Request('GET', Uri.parse('https://example.com'))),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('passes through successful responses', () async {
    final client = TimeoutHttpClient(
      _FakeClient(
        onSend: (_) async =>
            http.StreamedResponse(Stream<List<int>>.value(<int>[1, 2, 3]), 200),
      ),
      timeout: const Duration(seconds: 1),
    );

    final response = await client.send(
      http.Request('GET', Uri.parse('https://example.com')),
    );

    expect(response.statusCode, equals(200));
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient({required this.onSend});

  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return onSend(request);
  }
}
