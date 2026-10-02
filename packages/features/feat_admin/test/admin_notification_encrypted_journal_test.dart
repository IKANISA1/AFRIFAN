import 'dart:convert';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'notification_command_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual journal encrypts durable original attempt and reopens under original scope',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'notification-journal-',
      );
      Hive.init(directory.path);
      HiveEncryptionService.resetForTest();
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            storageChannel,
            (call) async => call.method == 'read'
                ? base64Encode(List.filled(32, 71))
                : null,
          );
      addTearDown(() async {
        await Hive.close();
        HiveEncryptionService.resetForTest();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(storageChannel, null);
        await directory.delete(recursive: true);
      });
      final journal = HiveAdminNotificationJournal();
      final attempt = AdminNotificationAttempt(
        userId: notificationTestUser,
        clubId: 24,
        operationId: notificationTestOperation,
        arguments: {
          'title': 'Private team alert',
          'body': 'Venue update',
          'audience': 'all_fans',
          'delivery_mode': 'send_now',
        },
      );
      await expectLater(
        journal.save(attempt.scope, null, attempt.encode()),
        throwsStateError,
      );
      expect(await directory.list().isEmpty, isTrue);
      await HiveEncryptionService.initialize();
      expect(HiveEncryptionService.cipher, isNotNull);
      await journal.runExclusive(attempt.scope, () async {
        await journal.save(attempt.scope, null, attempt.encode());
      });
      final file = File(
        '${directory.path}/africlub_admin_notification_v1.hive',
      );
      final bytes = latin1.decode(await file.readAsBytes());
      expect(bytes, isNot(contains('Private team alert')));
      expect(bytes, isNot(contains(notificationTestOperation)));
      await Hive.close();
      HiveEncryptionService.resetForTest();
      await HiveEncryptionService.initialize();
      final relaunched = HiveAdminNotificationJournal();
      final original = AdminNotificationAttempt.decode(
        await relaunched.read(attempt.scope),
        notificationTestUser,
        24,
      );
      expect(original!.operationId, notificationTestOperation);
      expect(original.arguments, attempt.arguments);
      expect(
        await relaunched.read('africlub-notification-v1:24:other-account'),
        isNull,
      );
      await expectLater(
        relaunched.save(attempt.scope, null, 'replacement'),
        throwsStateError,
      );
      expect(await relaunched.read(attempt.scope), attempt.encode());
    },
  );
}
