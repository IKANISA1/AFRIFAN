import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/account_closure_receipt.dart';

/// Stores one opaque receipt across logout/relaunch; every write is read back.
class AccountClosureStore {
  static const key = 'africlub.account_closure.receipt.v1';
  static final capabilityPattern = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  );
  Future<AccountClosureReceipt?> read() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final raw = preferences.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final id = json['request_id'];
      final status = json['status'];
      if (id is! String ||
          !capabilityPattern.hasMatch(id) ||
          status is! String ||
          !const {
            'requesting',
            'deletion_pending',
            'failed',
            'completed',
          }.contains(status)) {
        return null;
      }
      return AccountClosureReceipt(requestId: id, status: status);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AccountClosureReceipt receipt) async {
    if (!capabilityPattern.hasMatch(receipt.requestId)) {
      throw StateError('Invalid account closure capability.');
    }
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(receipt.toJson());
    if (!await preferences.setString(key, encoded)) {
      throw StateError('Cannot retain account closure reference.');
    }
    await preferences.reload();
    if (preferences.getString(key) != encoded) {
      throw StateError('Account closure reference readback failed.');
    }
  }

  Future<AccountClosureReceipt> prepare() async {
    final existing = await read();
    if (existing != null && !existing.isComplete) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final receipt = AccountClosureReceipt(
      requestId:
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
      status: 'requesting',
    );
    await save(receipt);
    return receipt;
  }

  Future<void> forget() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(key)) {
      throw StateError('Cannot hide account closure reference.');
    }
  }
}
