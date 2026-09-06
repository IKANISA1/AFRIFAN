import 'dart:async';
import 'package:feat_admin/src/admin_predict_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Gateway implements AdminPredictGateway {
  int mutations = 0;
  Object? error;
  Completer<void>? pending;
  @override
  Future<AdminPredictData> load() async {
    if (error case final e?) throw e;
    return const AdminPredictData(enabled: true);
  }

  @override
  Future<void> command(
    PredictAdminAction action,
    Map<String, Object?> params,
  ) async {
    mutations++;
    if (pending case final p?) await p.future;
  }
}

void main() {
  test(
    'admin commands serialize and timeout requires reconciliation',
    () async {
      final g = Gateway()..pending = Completer();
      final c = AdminPredictController(
        g,
        autoLoad: false,
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(c.dispose);
      await c.refresh();
      final first = c.command(PredictAdminAction.settle, {'p_pool_id': 'pool'});
      await c.command(PredictAdminAction.refund, {'p_pool_id': 'pool'});
      expect(g.mutations, 1);
      await first;
      expect(c.state.failed, isTrue);
      expect(c.state.canAct, isFalse);
      await c.command(PredictAdminAction.settle, {});
      expect(g.mutations, 1);
      await c.refresh();
      expect(c.state.canAct, isTrue);
    },
  );
  test(
    'failed read retains ledger but revocation clears private rows',
    () async {
      final g = Gateway();
      final c = AdminPredictController(g, autoLoad: false);
      addTearDown(c.dispose);
      await c.refresh();
      g.error = Exception('unavailable');
      await c.refresh();
      expect(c.state.data, isNotNull);
      expect(c.state.canAct, isFalse);
      g.error = const PostgrestException(
        message: 'PREDICT_ADMIN_REQUIRED',
        code: '42501',
      );
      await c.refresh();
      expect(c.state.data, isNull);
      expect(c.state.denied, isTrue);
    },
  );
}
