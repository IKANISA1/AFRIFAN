import 'dart:convert';
import 'package:core_auth/core_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'original cryptographic capability is durable before request and reused after relaunch',
    () async {
      final first = await AccountClosureStore().prepare();
      expect(
        AccountClosureStore.capabilityPattern.hasMatch(first.requestId),
        isTrue,
      );
      expect(first.status, 'requesting');
      final restarted = await AccountClosureStore().prepare();
      expect(restarted.requestId, first.requestId);
      final preferences = await SharedPreferences.getInstance();
      final data = jsonDecode(preferences.getString(AccountClosureStore.key)!);
      expect(data.keys.toSet(), {'request_id', 'status'});
      expect(data.toString(), isNot(contains('user_id')));
    },
  );
  test(
    'pending and failed receipts never imply completed deletion or generate a second request',
    () async {
      final original = await AccountClosureStore().prepare();
      for (final state in ['deletion_pending', 'failed']) {
        await AccountClosureStore().save(
          AccountClosureReceipt(requestId: original.requestId, status: state),
        );
        final recovered = await AccountClosureStore().prepare();
        expect(recovered.requestId, original.requestId);
        expect(recovered.status, state);
        expect(recovered.isComplete, isFalse);
      }
    },
  );
  test(
    'completed receipt remains readable and a later explicit request creates a fresh capability',
    () async {
      final original = await AccountClosureStore().prepare();
      await AccountClosureStore().save(
        AccountClosureReceipt(
          requestId: original.requestId,
          status: 'completed',
        ),
      );
      expect((await AccountClosureStore().read())!.isComplete, isTrue);
      expect(
        (await AccountClosureStore().prepare()).requestId,
        isNot(original.requestId),
      );
    },
  );
  test(
    'corrupt or guessable receipt is rejected and hide affects only local receipt',
    () async {
      SharedPreferences.setMockInitialValues({
        AccountClosureStore.key: '{"request_id":"1","status":"completed"}',
      });
      expect(await AccountClosureStore().read(), isNull);
      await AccountClosureStore().prepare();
      await AccountClosureStore().forget();
      expect(await AccountClosureStore().read(), isNull);
    },
  );
}
