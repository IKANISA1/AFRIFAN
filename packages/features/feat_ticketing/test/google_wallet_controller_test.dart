import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_ticketing/src/providers/google_wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test(
    'issues a server pass before opening the native Wallet save flow',
    () async {
      final calls = <String>[];
      final controller = GoogleWalletController(
        ticketId: 'ticket-1',
        passGateway: _PassGateway(
          onIssue: (ticketId) async {
            calls.add('issue:$ticketId');
            return 'signed-jwt';
          },
        ),
        platformGateway: _PlatformGateway(
          onAvailable: () async {
            calls.add('availability');
            return true;
          },
          onSave: (jwt) async {
            calls.add('save:$jwt');
            return GoogleWalletSaveResult.saved;
          },
        ),
      );

      await controller.add();

      expect(calls, <String>[
        'availability',
        'issue:ticket-1',
        'save:signed-jwt',
      ]);
      expect(controller.state.phase, GoogleWalletAddPhase.added);
    },
  );

  test('fails before pass issuance while offline', () async {
    ConnectivityService.setOnlineForTest(false);
    var issued = false;
    final controller = GoogleWalletController(
      ticketId: 'ticket-1',
      passGateway: _PassGateway(
        onIssue: (_) async {
          issued = true;
          return 'signed-jwt';
        },
      ),
      platformGateway: _PlatformGateway(),
    );

    await controller.add();

    expect(issued, isFalse);
    expect(controller.state.phase, GoogleWalletAddPhase.failed);
    expect(controller.state.failure?.kind, GoogleWalletFailureKind.offline);
  });

  test('does not request a pass when Google Wallet is unavailable', () async {
    var issued = false;
    final controller = GoogleWalletController(
      ticketId: 'ticket-1',
      passGateway: _PassGateway(
        onIssue: (_) async {
          issued = true;
          return 'signed-jwt';
        },
      ),
      platformGateway: _PlatformGateway(onAvailable: () async => false),
    );

    await controller.add();

    expect(issued, isFalse);
    expect(controller.state.failure?.kind, GoogleWalletFailureKind.unavailable);
  });

  test(
    'reports user cancellation without claiming the pass was saved',
    () async {
      final controller = GoogleWalletController(
        ticketId: 'ticket-1',
        passGateway: _PassGateway(onIssue: (_) async => 'signed-jwt'),
        platformGateway: _PlatformGateway(
          onSave: (_) async => GoogleWalletSaveResult.cancelled,
        ),
      );

      await controller.add();

      expect(controller.state.phase, GoogleWalletAddPhase.cancelled);
    },
  );

  test('coalesces overlapping add requests', () async {
    final pending = Completer<String>();
    var issueCalls = 0;
    final controller = GoogleWalletController(
      ticketId: 'ticket-1',
      passGateway: _PassGateway(
        onIssue: (_) {
          issueCalls += 1;
          return pending.future;
        },
      ),
      platformGateway: _PlatformGateway(),
    );

    final first = controller.add();
    final second = controller.add();
    pending.complete('signed-jwt');
    await Future.wait(<Future<void>>[first, second]);

    expect(issueCalls, 1);
    expect(controller.state.phase, GoogleWalletAddPhase.added);
  });

  test('maps a safe Edge Function payment code without exposing details', () {
    final failure = GoogleWalletFailure.fromError(
      const FunctionException(
        status: 409,
        details: <String, Object?>{
          'code': 'PAYMENT_PENDING',
          'error': 'internal text that must not be displayed',
        },
      ),
    );

    expect(failure.kind, GoogleWalletFailureKind.paymentPending);
  });
}

class _PassGateway implements GoogleWalletPassGateway {
  _PassGateway({required this.onIssue});

  final Future<String> Function(String ticketId) onIssue;

  @override
  Future<String> issueSaveJwt(String ticketId) => onIssue(ticketId);
}

class _PlatformGateway implements GoogleWalletPlatformGateway {
  _PlatformGateway({
    Future<bool> Function()? onAvailable,
    Future<GoogleWalletSaveResult> Function(String jwt)? onSave,
  }) : _onAvailable = onAvailable ?? (() async => true),
       _onSave = onSave ?? ((_) async => GoogleWalletSaveResult.saved);

  final Future<bool> Function() _onAvailable;
  final Future<GoogleWalletSaveResult> Function(String jwt) _onSave;

  @override
  Future<bool> isAvailable() => _onAvailable();

  @override
  Future<GoogleWalletSaveResult> savePassJwt(String jwt) => _onSave(jwt);
}
