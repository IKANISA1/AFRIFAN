import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crashlytics_service.dart';
import 'supabase_client_factory.dart';

/// Result of a safe RPC call, wrapping either success data or an error.
///
/// Used to avoid raw exception throwing from repository calls, giving
/// callers a structured way to handle both success and failure states
/// (loading/empty/error).
class RpcResult<T> {
  const RpcResult({this.data, this.error, this.isSuccess = false});

  /// Successful result with data.
  const RpcResult.success(T this.data) : error = null, isSuccess = true;

  /// Failed result with an error description.
  const RpcResult.failure(String this.error) : data = null, isSuccess = false;

  final T? data;
  final String? error;
  final bool isSuccess;

  /// Unwrap the data, throwing [StateError] if this is a failure.
  T get requireData {
    if (!isSuccess || data == null) {
      throw StateError('RpcResult.requireData called on a failure: $error');
    }
    return data as T;
  }
}

/// Safe RPC wrapper with timeout, retry, and error normalization.
///
/// Every Supabase RPC call in repositories should go through this utility
/// to ensure consistent behavior on slow/intermittent African mobile networks:
/// - **Timeout**: 15 seconds per attempt (prevents infinite hangs / ANRs)
/// - **Retry**: Up to 3 attempts with exponential backoff (1s, 2s, 4s)
/// - **Error normalization**: All errors become user-friendly strings
/// - **Crashlytics**: Non-fatal errors are recorded for production diagnostics
///
/// Usage:
/// ```dart
/// final result = await SafeRpc.call(
///   'prediction_get_dashboard',
///   tag: 'PredictionRepo',
/// );
/// if (result.isSuccess) {
///   return PredictionDashboard.fromJson(result.requireData);
/// }
/// ```
class SafeRpc {
  SafeRpc._();

  /// Default timeout per RPC attempt.
  static const _timeout = Duration(seconds: 15);

  /// Maximum retry attempts (including the first attempt).
  static const _maxAttempts = 3;

  /// Base delay for exponential backoff.
  static const _baseDelay = Duration(seconds: 1);

  /// Execute a Supabase RPC call with timeout, retry, and error handling.
  ///
  /// [functionName] — the name of the Supabase function to invoke.
  /// [params] — optional parameters to pass to the RPC.
  /// [tag] — a log tag for diagnostics (e.g., 'PredictionRepo').
  /// [timeout] — override the default 15s timeout.
  /// [maxAttempts] — override the default 3 retry attempts.
  static Future<RpcResult<dynamic>> call(
    String functionName, {
    Map<String, dynamic>? params,
    String tag = 'SafeRpc',
    Duration? timeout,
    int? maxAttempts,
    Duration? backoffBase,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final effectiveMaxAttempts = maxAttempts ?? _maxAttempts;
    final effectiveBackoffBase = backoffBase ?? _baseDelay;

    Object? lastError;

    for (var attempt = 1; attempt <= effectiveMaxAttempts; attempt++) {
      try {
        final response = await SupabaseClientFactory.client
            .rpc(functionName, params: params ?? const <String, dynamic>{})
            .timeout(effectiveTimeout);

        return RpcResult<dynamic>.success(response);
      } on TimeoutException {
        lastError = TimeoutException(
          '$functionName timed out after ${effectiveTimeout.inSeconds}s',
        );
        if (attempt < effectiveMaxAttempts) {
          final delay = _delayForAttempt(
            attempt,
            baseDelay: effectiveBackoffBase,
          );
          AfriLogger.warn(
            tag,
            'RPC "$functionName" attempt $attempt/$effectiveMaxAttempts '
            'timed out. Retrying in ${delay.inSeconds}s…',
          );
          await Future<void>.delayed(delay);
        }
      } on PostgrestException catch (error) {
        // Postgrest errors are generally not transient — don't retry.
        final userMessage = _normalizePostgrestError(error);
        AfriLogger.error(tag, 'RPC "$functionName" failed: $userMessage');
        await CrashlyticsService.recordError(
          error,
          StackTrace.current,
          reason: 'RPC $functionName PostgREST error',
        );
        return RpcResult<dynamic>.failure(userMessage);
      } catch (error, stackTrace) {
        lastError = error;
        if (_isTransient(error) && attempt < effectiveMaxAttempts) {
          final delay = _delayForAttempt(
            attempt,
            baseDelay: effectiveBackoffBase,
          );
          AfriLogger.warn(
            tag,
            'RPC "$functionName" attempt $attempt/$effectiveMaxAttempts '
            'failed: $error. Retrying in ${delay.inSeconds}s…',
          );
          await Future<void>.delayed(delay);
        } else {
          AfriLogger.error(
            tag,
            'RPC "$functionName" failed on attempt $attempt.',
            error,
            stackTrace,
          );
          await CrashlyticsService.recordError(
            error,
            stackTrace,
            reason: 'RPC $functionName attempt $attempt',
          );
          return RpcResult<dynamic>.failure(_normalizeError(error));
        }
      }
    }

    // All attempts exhausted.
    AfriLogger.error(
      tag,
      'RPC "$functionName" failed after $effectiveMaxAttempts attempts.',
      lastError,
    );
    if (lastError != null) {
      await CrashlyticsService.recordError(
        lastError,
        StackTrace.current,
        reason: 'RPC $functionName exhausted $effectiveMaxAttempts attempts',
      );
    }

    return const RpcResult<dynamic>.failure(
      'Request timed out. Please check your connection and try again.',
    );
  }

  /// Execute a Supabase query (non-RPC) with timeout.
  ///
  /// For table selects, inserts, updates, deletes that return data.
  /// Does NOT retry by default (most queries are idempotent reads, but
  /// writes should be handled carefully).
  static Future<RpcResult<T>> query<T>(
    Future<T> Function() queryFn, {
    String tag = 'SafeRpc',
    String description = 'query',
    Duration? timeout,
    int maxAttempts = 2,
    Duration? backoffBase,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final effectiveBackoffBase = backoffBase ?? _baseDelay;
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await queryFn().timeout(effectiveTimeout);
        return RpcResult<T>.success(result);
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < maxAttempts) {
          final delay = _delayForAttempt(
            attempt,
            baseDelay: effectiveBackoffBase,
          );
          AfriLogger.warn(
            tag,
            '$description timed out on attempt $attempt/$maxAttempts. '
            'Retrying in ${delay.inSeconds}s…',
          );
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
          continue;
        }
        AfriLogger.warn(tag, '$description timed out.');
        return RpcResult<T>.failure(
          'Request timed out. Please check your connection and try again.',
        );
      } on PostgrestException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        final userMessage = _normalizePostgrestError(error);
        AfriLogger.error(tag, '$description failed: $userMessage');
        await CrashlyticsService.recordError(
          error,
          stackTrace,
          reason: '$tag $description',
        );
        return RpcResult<T>.failure(userMessage);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (_isTransient(error) && attempt < maxAttempts) {
          final delay = _delayForAttempt(
            attempt,
            baseDelay: effectiveBackoffBase,
          );
          AfriLogger.warn(
            tag,
            '$description failed on attempt $attempt/$maxAttempts: $error. '
            'Retrying in ${delay.inSeconds}s…',
          );
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
          continue;
        }
        AfriLogger.error(tag, '$description failed.', error, stackTrace);
        await CrashlyticsService.recordError(
          error,
          stackTrace,
          reason: '$tag $description',
        );
        return RpcResult<T>.failure(_normalizeError(error));
      }
    }

    await CrashlyticsService.recordError(
      lastError ?? StateError('$description failed unexpectedly.'),
      lastStackTrace ?? StackTrace.current,
      reason: '$tag $description exhausted retries',
    );
    return RpcResult<T>.failure(
      _normalizeError(
        lastError ?? StateError('$description failed unexpectedly.'),
      ),
    );
  }

  /// Whether the error is likely transient and worth retrying.
  static bool _isTransient(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('network') ||
        message.contains('eof') ||
        message.contains('reset by peer');
  }

  /// Normalize a [PostgrestException] into a user-friendly string.
  static String _normalizePostgrestError(PostgrestException error) {
    // Common RPC-level errors with user-friendly messages.
    if (error.code == '42501') {
      return 'You do not have permission for this action.';
    }
    if (error.code == '23505') {
      return 'This entry already exists.';
    }
    if (error.code == 'PGRST116') {
      return 'No matching record found.';
    }
    if (error.message.contains('JWT')) {
      return 'Your session has expired. Please sign in again.';
    }

    // Fall back to the Postgrest message (which is generally safe to show).
    return error.message.isNotEmpty
        ? error.message
        : 'Something went wrong. Please try again.';
  }

  /// Normalize any error into a user-friendly string.
  static String _normalizeError(Object error) {
    if (error is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    }
    if (error is FunctionException) {
      final detailsMessage = _extractFunctionErrorMessage(error.details);
      if (detailsMessage != null) {
        return detailsMessage;
      }
      if (error.status == 401) {
        return 'Your session has expired. Please sign in again.';
      }
      if (error.status == 403) {
        return 'This feature is currently unavailable.';
      }
      if (error.status == 429) {
        return 'Too many requests. Please try again shortly.';
      }
    }
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection refused')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String? _extractFunctionErrorMessage(dynamic details) {
    if (details is Map) {
      final rawMessage = details['error'] ?? details['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        return rawMessage.trim();
      }
    }

    if (details is String && details.trim().isNotEmpty) {
      return details.trim();
    }

    return null;
  }

  static Duration _delayForAttempt(int attempt, {required Duration baseDelay}) {
    if (baseDelay <= Duration.zero) {
      return Duration.zero;
    }
    return baseDelay * (1 << (attempt - 1));
  }
}
