import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('africlub_queue_test_');
    Hive.init(tempDir.path);
    ConnectivityService.setOnlineForTest(true);
    await OfflineEventQueue.resetForTest(deleteBox: true);
  });

  tearDown(() async {
    await OfflineEventQueue.resetForTest(deleteBox: true);
    ConnectivityService.setOnlineForTest(true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('queues payload locally while offline', () async {
    final sent = <Map<String, dynamic>>[];
    ConnectivityService.setOnlineForTest(false);
    await OfflineEventQueue.initialize((payload) async {
      sent.add(payload);
    });

    await OfflineEventQueue.enqueue(
      service: 'mobile_app',
      component: 'bootstrap',
      message: 'offline failure',
      status: OperationalHealthStatus.error,
    );

    expect(sent, isEmpty);
    expect(OfflineEventQueue.pendingCount, equals(1));
  });

  test('flushes queued payload when connectivity returns', () async {
    final sent = <Map<String, dynamic>>[];
    ConnectivityService.setOnlineForTest(false);
    await OfflineEventQueue.initialize((payload) async {
      sent.add(payload);
    });

    await OfflineEventQueue.enqueue(
      service: 'mobile_app',
      component: 'bootstrap',
      message: 'offline failure',
      status: OperationalHealthStatus.error,
    );

    ConnectivityService.setOnlineForTest(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(sent, hasLength(1));
    expect(sent.single['message'], equals('offline failure'));
    expect(OfflineEventQueue.pendingCount, equals(0));
  });
}
