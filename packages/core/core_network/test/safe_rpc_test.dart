import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('RpcResult', () {
    test('success wraps data correctly', () {
      const result = RpcResult<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.data, equals(42));
      expect(result.error, isNull);
      expect(result.requireData, equals(42));
    });

    test('failure wraps error correctly', () {
      const result = RpcResult<int>.failure('Something went wrong');
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.error, equals('Something went wrong'));
    });

    test('requireData throws on failure', () {
      const result = RpcResult<int>.failure('fail');
      expect(() => result.requireData, throwsA(isA<StateError>()));
    });

    test('success with null data', () {
      const result = RpcResult<String?>.success(null);
      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });
  });

  group('SafeRpc.query', () {
    test('returns success on successful query', () async {
      final result = await SafeRpc.query<int>(
        () async => 42,
        tag: 'Test',
        description: 'test query',
      );

      expect(result.isSuccess, isTrue);
      expect(result.requireData, equals(42));
    });

    test('returns failure on timeout', () async {
      final result = await SafeRpc.query<int>(
        () async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return 42;
        },
        tag: 'Test',
        description: 'slow query',
        timeout: const Duration(milliseconds: 100),
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('timed out'));
    });

    test('returns failure on generic exception', () async {
      final result = await SafeRpc.query<int>(
        () async => throw Exception('db error'),
        tag: 'Test',
        description: 'failing query',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('returns correct type for list results', () async {
      final result = await SafeRpc.query<List<String>>(
        () async => <String>['a', 'b', 'c'],
        tag: 'Test',
      );

      expect(result.isSuccess, isTrue);
      expect(result.requireData, hasLength(3));
    });

    test('returns correct type for nullable results', () async {
      final result = await SafeRpc.query<String?>(
        () async => null,
        tag: 'Test',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });

    test('retries transient failures before succeeding', () async {
      var attempts = 0;
      final result = await SafeRpc.query<int>(
        () async {
          attempts += 1;
          if (attempts < 3) {
            throw const SocketException('temporary outage');
          }
          return 42;
        },
        tag: 'Test',
        description: 'retry query',
        maxAttempts: 3,
        backoffBase: Duration.zero,
      );

      expect(result.isSuccess, isTrue);
      expect(result.requireData, equals(42));
      expect(attempts, equals(3));
    });
  });

  group('SafeRpc error normalization', () {
    test('normalizes SocketException to user-friendly message', () async {
      final result = await SafeRpc.query<int>(
        () async => throw const SocketException('Connection refused'),
        tag: 'Test',
        description: 'socket test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('internet connection'));
    });

    test('normalizes TimeoutException to user-friendly message', () async {
      final result = await SafeRpc.query<int>(
        () async => throw TimeoutException('timed out'),
        tag: 'Test',
        description: 'timeout test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('timed out'));
    });

    test('normalizes unknown errors gracefully', () async {
      final result = await SafeRpc.query<int>(
        () async => throw 'raw string error',
        tag: 'Test',
        description: 'raw test',
      );

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotEmpty);
    });

    test('preserves function exception payload errors', () async {
      final result = await SafeRpc.query<int>(
        () async => throw const FunctionException(
          status: 403,
          details: <String, Object?>{
            'error': "The feature 'fan_clubs' is not available (global_disabled).",
          },
        ),
        tag: 'Test',
        description: 'feature-disabled function',
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.error,
        "The feature 'fan_clubs' is not available (global_disabled).",
      );
    });
  });
}

/// Minimal SocketException to test error normalization without importing dart:io.
class SocketException implements Exception {
  const SocketException(this.message);
  final String message;

  @override
  String toString() => 'SocketException: $message';
}
