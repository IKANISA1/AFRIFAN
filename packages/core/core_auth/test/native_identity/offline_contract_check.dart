/// Portable smoke: runs with Dart alone and never initializes Flutter/Supabase.
library;

import 'dart:async';
import 'dart:io';

import 'package:core_auth/native_identity.dart';

Future<void> main() async {
  final scope = NativeIdentityScope(
    applicationId: 'com.africlub.rayon',
    approvedOrigin: Uri.parse('https://identity.test.invalid'),
    clubId: 24,
  );
  final transport = _NeverTransport();
  final client = NativeIdentityWireClient(
    scope: scope,
    transport: transport,
    enabled: true,
    timeout: const Duration(milliseconds: 10),
  );
  final unavailable = NativeIdentityController(client: client, enabled: true);
  try {
    await unavailable.issueChallenge('+10000000001');
    throw StateError('unavailable store accepted');
  } on NativeIdentityFailure catch (error) {
    if (error.code != NativeIdentityError.storageUnavailable ||
        transport.calls != 0) {
      throw StateError('store gate failed');
    }
  }
  final secret = SecureNativeIdentityEntropy().clientSecret();
  if (!identitySecret(secret)) {
    throw StateError('secure entropy contract failed');
  }
  final watch = Stopwatch()..start();
  try {
    await client.challenge('+10000000001', secret, 'original_operation_key');
    throw StateError('unbounded transport accepted');
  } on NativeIdentityFailure catch (error) {
    if (error.code != NativeIdentityError.responseDeadline ||
        error.outcome != NativeIdentityOutcome.unknown ||
        transport.calls != 1 ||
        watch.elapsedMilliseconds > 500) {
      throw StateError('transport deadline failed');
    }
  }
  final journal = NativeIdentityJournal(scope: scope).encodeProtected();
  if (NativeIdentityJournal.decodeProtected(journal, scope).revision != 0) {
    throw StateError('journal binding failed');
  }
  // Only finite status is emitted; secret, token and body values are excluded.
  stdout.writeln(
    'Native identity portable contract checks passed; external calls: 0.',
  );
}

final class _NeverTransport implements NativeIdentityTransport {
  var calls = 0;
  @override
  Future<NativeIdentityResponse> send(
    NativeIdentityRequest request,
    Duration timeout,
  ) {
    calls++;
    return Completer<NativeIdentityResponse>().future;
  }
}
