import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_command_test_support.dart';

const arguments = <String, dynamic>{
  'title': 'Matchday alert',
  'body': 'Kickoff soon.',
  'audience': 'all_fans',
  'delivery_mode': 'send_now',
};

void main() {
  test('canonical payload and hash agree with Edge and SQL vector', () {
    final normalized = normalizeNotificationArguments({
      ...arguments,
      'tier': 'gold',
      'group_id': 'unused',
      'scheduled_at': 'unused',
    });
    expect(normalized.keys.toList(), [
      'audience',
      'body',
      'delivery_mode',
      'group_id',
      'group_name',
      'image_url',
      'scheduled_at',
      'tier',
      'title',
    ]);
    expect(normalized['tier'], isNull);
    expect(normalized['scheduled_at'], isNull);
    expect(
      notificationArgumentsHash(normalized),
      'c33bcee02a35aa9aaf21b2d42c475b68316e248c970b4db4e8e8eeebaa67ec6b',
    );
    expect(
      normalizeNotificationArguments({
        ...arguments,
        'image_url': 'https://EXAMPLE.test:443',
      })['image_url'],
      'https://example.test/',
    );
    expect(
      normalizeNotificationArguments({
        ...arguments,
        'image_url': 'https://example.test/a/../b',
      })['image_url'],
      'https://example.test/b',
    );
    final date = normalizeNotificationArguments({
      ...arguments,
      'delivery_mode': 'schedule',
      'scheduled_at': '2026-10-02T10:23:12.123456+02:00',
    });
    expect(date['scheduled_at'], '2026-10-02T08:23:12.123Z');
    expect(
      () => normalizeNotificationArguments({
        ...arguments,
        'actor_id': notificationTestUser,
      }),
      throwsFormatException,
    );
    expect(
      () => normalizeNotificationArguments({
        ...arguments,
        'image_url': 'file:///private',
      }),
      throwsFormatException,
    );
    expect(
      () => normalizeNotificationArguments({
        ...arguments,
        'audience': 'by_group',
        'group_id': 'invalid',
      }),
      throwsFormatException,
    );
  });

  test(
    'durable original is saved before actual transport; missing persistence stops mutation',
    () async {
      final journal = MemoryNotificationJournal();
      var requests = 0;
      final flow = _flow(journal, (attempt, submit) async {
        requests++;
        expect(await journal.read(attempt.scope), attempt.encode());
        expect(submit, isTrue);
        return notificationTestReceipt(attempt);
      });
      journal.failWrites = true;
      await expectLater(flow.submit(arguments), throwsStateError);
      expect(requests, 0);
      journal.failWrites = false;
      final result = await flow.submit(arguments);
      expect(result.confirmed, isTrue);
      expect(requests, 1);
      expect(journal.values, isEmpty);
    },
  );

  test(
    'lost response, relaunch, status absence and reviewed retry keep original UUID and payload',
    () async {
      final journal = MemoryNotificationJournal();
      final delayed = Completer<Map<String, dynamic>>();
      var creates = 0;
      final flow = _flow(journal, (attempt, submit) async {
        creates++;
        return delayed.future;
      }, timeout: const Duration(milliseconds: 1));
      await expectLater(
        flow.submit(arguments),
        throwsA(isA<TimeoutException>()),
      );
      final original = flow.attempt!;
      final relaunched = _flow(journal, (attempt, submit) async {
        expect(attempt.operationId, original.operationId);
        expect(attempt.arguments, original.arguments);
        if (submit) creates++;
        return notificationTestReceipt(
          attempt,
          state: submit ? 'completed' : 'not_admitted',
        );
      });
      await relaunched.restore();
      expect(relaunched.attempt!.operationId, original.operationId);
      final missing = await relaunched.recover();
      expect(missing!.state, 'not_admitted');
      expect(creates, 1);
      expect(journal.values, hasLength(1));
      await expectLater(
        relaunched.submit({...arguments, 'body': 'Changed'}),
        throwsStateError,
      );
      expect(creates, 1);
      await relaunched.resumeOriginal();
      expect(creates, 2);
      expect(journal.values, isEmpty);
      delayed.complete(notificationTestReceipt(original));
      await Future<void>.delayed(Duration.zero);
      expect(journal.values, isEmpty);
    },
  );

  for (final state in ['admitted', 'processing', 'unknown']) {
    test('$state status cannot resend the stored original', () async {
      final journal = MemoryNotificationJournal();
      var submits = 0;
      final flow = _flow(journal, (attempt, submit) async {
        if (submit) submits++;
        return notificationTestReceipt(
          attempt,
          state: state,
          status: state == 'unknown' ? 'unknown' : 'processing',
          sent: 0,
          unknown: state == 'unknown' ? 1 : 0,
          pending: state == 'unknown' ? 0 : 1,
        );
      });
      await flow.submit(arguments);
      final encoded = journal.values.values.single;
      await flow.recover();
      await flow.resumeOriginal();
      expect(submits, 1);
      expect(journal.values.values.single, encoded);
      expect(flow.receipt!.confirmed, isFalse);
    });
  }

  test(
    'foreign original identity, arguments hash and contradictory counters fail closed',
    () {
      final attempt = AdminNotificationAttempt(
        userId: notificationTestUser,
        clubId: 24,
        operationId: notificationTestOperation,
        arguments: arguments,
      );
      final raw = notificationTestReceipt(attempt);
      for (final key in [
        'operation_id',
        'actor_id',
        'arguments_sha256',
        'club_id',
      ]) {
        final changed = {
          ...raw,
          'command': {...(raw['command'] as Map), key: 'foreign'},
        };
        expect(
          () => AdminNotificationCommandReceipt.fromRaw(changed, attempt),
          throwsFormatException,
        );
      }
      expect(
        () => AdminNotificationCommandReceipt.fromRaw(
          notificationTestReceipt(attempt, state: 'completed', unknown: 1),
          attempt,
        ),
        throwsFormatException,
      );
      expect(
        () => AdminNotificationAttempt.decode(
          attempt.encode(),
          '99969000-0000-4000-8000-000000000002',
          24,
        ),
        throwsStateError,
      );
      expect(
        () => AdminNotificationAttempt.decode(
          attempt.encode(),
          notificationTestUser,
          25,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'logout/account or same-user login change while transport waits cannot clear or publish old receipt',
    () async {
      for (final change in ['logout', 'other-account', 'new-login']) {
        final journal = MemoryNotificationJournal();
        final delayed = Completer<Map<String, dynamic>>();
        var current = true;
        final flow = _flow(
          journal,
          (attempt, submit) => delayed.future,
          owner: notificationTestOwner(isCurrent: () => current),
        );
        final waiting = flow.submit(arguments);
        await Future<void>.delayed(Duration.zero);
        final original = flow.attempt!;
        current = false;
        delayed.complete(notificationTestReceipt(original));
        await expectLater(
          waiting,
          throwsA(isA<SupabaseSessionChangedException>()),
          reason: change,
        );
        expect(flow.receipt, isNull, reason: change);
        expect(journal.values.values.single, original.encode(), reason: change);
      }
    },
  );

  test(
    'two feature callers sharing durable scope admit only one original operation',
    () async {
      final journal = MemoryNotificationJournal();
      final delayed = Completer<Map<String, dynamic>>();
      var calls = 0;
      final first = _flow(journal, (attempt, submit) {
        calls++;
        return delayed.future;
      });
      final second = _flow(journal, (attempt, submit) {
        calls++;
        return delayed.future;
      });
      final pending = first.submit(arguments);
      await Future<void>.delayed(Duration.zero);
      final competing = second.submit(arguments);
      delayed.complete(
        notificationTestReceipt(
          first.attempt!,
          state: 'processing',
          status: 'processing',
          pending: 1,
          sent: 0,
        ),
      );
      await pending;
      await expectLater(competing, throwsStateError);
      expect(calls, 1);
      expect(journal.values, hasLength(1));
    },
  );
}

AdminNotificationCommandFlow _flow(
  MemoryNotificationJournal journal,
  NotificationCommandTransport transport, {
  AdminNotificationOwner? owner,
  Duration timeout = const Duration(seconds: 12),
}) => AdminNotificationCommandFlow(
  journal: journal,
  owner: owner ?? notificationTestOwner(),
  transport: transport,
  operationFactory: () => notificationTestOperation,
  timeout: timeout,
);
