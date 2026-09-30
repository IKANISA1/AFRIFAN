import 'dart:convert';
import 'dart:math';

import 'models.dart';

final class NativeIdentityRequest {
  NativeIdentityRequest(
    this.uri,
    this.method,
    Map<String, String> headers,
    this.body,
  ) : headers = Map.unmodifiable(headers);
  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final String? body;
  @override
  String toString() => 'NativeIdentityRequest([protected])';
}

final class NativeIdentityResponse {
  NativeIdentityResponse(this.status, Map<String, String> headers, this.body)
    : headers = Map.unmodifiable(headers);
  final int status;
  final Map<String, String> headers;
  final String body;
  @override
  String toString() => 'NativeIdentityResponse([protected])';
}

abstract interface class NativeIdentityTransport {
  /// Exactly one network submission, trusted TLS, no redirects/cookies/logging.
  /// The wire client also bounds this future when cancellation is ignored.
  Future<NativeIdentityResponse> send(
    NativeIdentityRequest request,
    Duration timeout,
  );
}

/// All capabilities must be independently validated on physical target devices.
/// Declaring these fields is a port contract, not proof of an adapter's security.
/// boundedOperations means bounded caller-observed replies; OS work can continue
/// after an acknowledgement is lost and must retain its exclusive lease.
final class NativeCredentialStoreCapabilities {
  const NativeCredentialStoreCapabilities({
    required this.osProtected,
    required this.atomicDurableCompareAndSet,
    required this.processSafeExclusive,
    required this.applicationOriginClubBinding,
    required this.boundedOperations,
  });
  const NativeCredentialStoreCapabilities.unavailable()
    : osProtected = false,
      atomicDurableCompareAndSet = false,
      processSafeExclusive = false,
      applicationOriginClubBinding = false,
      boundedOperations = false;
  final bool osProtected,
      atomicDurableCompareAndSet,
      processSafeExclusive,
      applicationOriginClubBinding,
      boundedOperations;
  bool get usable =>
      osProtected &&
      atomicDurableCompareAndSet &&
      processSafeExclusive &&
      applicationOriginClubBinding &&
      boundedOperations;
}

abstract interface class NativeCredentialTransaction {
  /// Raw protected journal; no preferences, plaintext files, debug dumps or logs.
  Future<String?> read();

  /// Atomically commits and durably acknowledges exactly this replacement.
  /// A false result means no write. Lost acknowledgements may have committed;
  /// the caller rereads on the next explicit action instead of inventing a key.
  Future<bool> compareAndSet(String? expected, String replacement);
}

abstract interface class NativeCredentialStore {
  NativeCredentialStoreCapabilities get capabilities;

  /// Lock all isolates and processes for this bound application/origin/club.
  /// Bound acquisition by acquisitionTimeout, including each channel attempt.
  /// Invoke work at most once. Release only after work AND every issued native
  /// read/CAS settle, including after disposal or a caller-observed timeout.
  /// Queue release behind issued OS work; never force-unlock on a lease TTL.
  /// Each read/CAS reply must have a bounded caller-observed deadline. A late CAS
  /// can still commit; the next explicit action must reread the durable journal.
  Future<T> runExclusive<T>(
    NativeIdentityScope scope,
    Duration acquisitionTimeout,
    Future<T> Function(NativeCredentialTransaction transaction) work,
  );
}

/// Production default until a separate accepted credential channel exists.
/// The financial checkout marker channel must never store identity credentials.
final class UnavailableNativeCredentialStore implements NativeCredentialStore {
  const UnavailableNativeCredentialStore();
  @override
  NativeCredentialStoreCapabilities get capabilities =>
      const NativeCredentialStoreCapabilities.unavailable();
  @override
  Future<T> runExclusive<T>(
    NativeIdentityScope scope,
    Duration acquisitionTimeout,
    Future<T> Function(NativeCredentialTransaction transaction) work,
  ) async {
    throw const NativeIdentityFailure(NativeIdentityError.storageUnavailable);
  }
}

abstract interface class NativeIdentityEntropy {
  String requestKey();
  String clientSecret();
}

final class SecureNativeIdentityEntropy implements NativeIdentityEntropy {
  SecureNativeIdentityEntropy() : _random = Random.secure();
  final Random _random;
  List<int> _bytes(int count) =>
      List.generate(count, (_) => _random.nextInt(256));
  @override
  String clientSecret() => base64Url.encode(_bytes(32)).replaceAll('=', '');
  @override
  String requestKey() {
    final bytes = _bytes(16);
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
