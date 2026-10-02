import 'dart:async';

import 'package:feat_admin/feat_admin.dart';

const notificationTestUser = '99969000-0000-4000-8000-000000000001';
const notificationTestOperation = '99969000-0000-4000-8000-000000000101';
const notificationTestId = '99969000-0000-4000-8000-000000000201';

class MemoryNotificationJournal implements AdminNotificationJournal {
  final values = <String, String>{};
  final locks = <String, Future<void>>{};
  bool failWrites = false;
  @override
  Future<T> runExclusive<T>(String scope, Future<T> Function() work) async {
    final previous = locks[scope] ?? Future<void>.value();
    final release = Completer<void>();
    final next = previous.then<void>((_) => release.future);
    unawaited(locks[scope] = next);
    await previous;
    try {
      return await work();
    } finally {
      release.complete();
      if (identical(locks[scope], next)) unawaited(locks.remove(scope));
    }
  }

  @override
  Future<String?> read(String scope) async => values[scope];
  @override
  Future<void> save(String scope, String? expected, String value) async {
    if (failWrites || values[scope] != expected) {
      throw StateError('JOURNAL_CONFLICT');
    }
    values[scope] = value;
  }

  @override
  Future<void> remove(String scope, String expected) async {
    if (failWrites || values[scope] != expected) {
      throw StateError('JOURNAL_CONFLICT');
    }
    values.remove(scope);
  }
}

AdminNotificationOwner notificationTestOwner({bool Function()? isCurrent}) =>
    AdminNotificationOwner(
      userId: notificationTestUser,
      clubId: 24,
      isCurrent: isCurrent ?? () => true,
      dispose: () async {},
    );

Map<String, dynamic> notificationTestReceipt(
  AdminNotificationAttempt attempt, {
  String state = 'completed',
  String status = 'sent',
  int unknown = 0,
  int pending = 0,
  int requested = 1,
  int sent = 1,
  int failed = 0,
}) => {
  'command': {
    'version': 1,
    'operation_id': attempt.operationId,
    'actor_id': attempt.userId,
    'club_id': attempt.clubId,
    'arguments_sha256': state == 'not_admitted'
        ? null
        : attempt.argumentsSha256,
    'notification_id': state == 'not_admitted' ? null : notificationTestId,
    'delivery_mode': state == 'not_admitted'
        ? null
        : attempt.arguments['delivery_mode'],
    'state': state,
  },
  'notification': state == 'not_admitted'
      ? null
      : {
          'id': notificationTestId,
          'club_id': attempt.clubId,
          'created_by': attempt.userId,
          'title': attempt.arguments['title'],
          'body': attempt.arguments['body'],
        },
  'delivery': state == 'not_admitted'
      ? null
      : {
          'status': status,
          'requested_recipient_count': requested,
          'successful_user_count': sent > 0 ? 1 : 0,
          'failed_user_count': failed > 0 ? 1 : 0,
          'sent_count': sent,
          'failed_count': failed,
          'cleaned_tokens': 0,
          'unknown_count': unknown,
          'pending_count': pending,
          'scheduled_at': attempt.arguments['scheduled_at'],
        },
};
