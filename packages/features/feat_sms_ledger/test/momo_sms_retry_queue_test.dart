import 'dart:io';

import 'package:feat_sms_ledger/src/repositories/momo_sms_ingestion_repository.dart';
import 'package:feat_sms_ledger/src/services/momo_sms_retry_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('retry_queue_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MomoSmsRetryQueue createQueue({int maxSize = 200}) {
    return MomoSmsRetryQueue(
      openBox: <T>(name) async {
        if (!Hive.isBoxOpen(name)) {
          return await Hive.openBox<T>(name);
        }
        return Hive.box<T>(name);
      },
      maxSize: maxSize,
    );
  }

  MomoSmsCapture capture({
    String key = 'key-1',
    String body =
        'You have received 5000 RWF. TxID: ABC123. New balance: 10000 RWF.',
  }) {
    return MomoSmsCapture(
      sender: 'MTN MoMo',
      body: body,
      deviceMessageKey: key,
      receivedAt: DateTime.utc(2026, 4, 15),
      ingestionSource: 'test',
    );
  }

  group('MomoSmsRetryQueue', () {
    test('enqueue and size', () async {
      final queue = createQueue();
      expect(await queue.size(), 0);

      final result = await queue.enqueue(capture());
      expect(result, isTrue);
      expect(await queue.size(), 1);
    });

    test('enqueue is idempotent for same key', () async {
      final queue = createQueue();

      await queue.enqueue(capture(key: 'dup'));
      await queue.enqueue(capture(key: 'dup'));

      expect(await queue.size(), 1);
    });

    test('rejects enqueue when at max capacity', () async {
      final queue = createQueue(maxSize: 2);

      await queue.enqueue(capture(key: 'a'));
      await queue.enqueue(capture(key: 'b'));
      final rejected = await queue.enqueue(capture(key: 'c'));

      expect(rejected, isFalse);
      expect(await queue.size(), 2);
    });

    test('drain removes successfully ingested items', () async {
      final queue = createQueue();
      await queue.enqueue(capture(key: 'ok-1'));
      await queue.enqueue(capture(key: 'ok-2'));

      final repo = _SuccessfulRepo();
      final result = await queue.drain(repo);

      expect(result.queuedBefore, 2);
      expect(result.queuedAfter, 0);
      expect(result.allCleared, isTrue);
      expect(result.drainedCount, 2);
    });

    test('drain keeps failed items in queue', () async {
      final queue = createQueue();
      await queue.enqueue(capture(key: 'fail-1'));
      await queue.enqueue(capture(key: 'ok-1'));

      final repo = _PartiallyFailingRepo(failKeys: {'fail-1'});
      final result = await queue.drain(repo);

      expect(result.queuedBefore, 2);
      expect(result.queuedAfter, 1);
      expect(result.allCleared, isFalse);
    });

    test('drain on empty queue returns zero counts', () async {
      final queue = createQueue();
      final repo = _SuccessfulRepo();
      final result = await queue.drain(repo);

      expect(result.hadEntries, isFalse);
      expect(result.queuedBefore, 0);
      expect(result.queuedAfter, 0);
    });

    test('serialized capture contains expected PII fields', () async {
      final queue = createQueue();
      final c = capture(body: 'Payment to 0781234567 of 5000 RWF');
      await queue.enqueue(c);

      final box = Hive.box<String>(momoSmsRetryQueueBoxName);
      final json = box.get(c.deviceMessageKey);

      expect(json, contains('0781234567'));
      expect(json, contains('5000 RWF'));
      expect(json, contains('MTN MoMo'));
    });
  });

  group('RetryQueueDrainResult', () {
    test('computed properties', () {
      const result = RetryQueueDrainResult(queuedBefore: 10, queuedAfter: 3);
      expect(result.drainedCount, 7);
      expect(result.allCleared, isFalse);
      expect(result.hadEntries, isTrue);
    });

    test('all cleared when queuedAfter is 0', () {
      const result = RetryQueueDrainResult(queuedBefore: 5, queuedAfter: 0);
      expect(result.allCleared, isTrue);
    });
  });

  group('MomoSmsIngestionRepository — sender validation', () {
    test('approves known MoMo sender IDs', () {
      expect(MomoSmsIngestionRepository.isApprovedSender('MTN MoMo'), isTrue);
      expect(MomoSmsIngestionRepository.isApprovedSender('M-Money'), isTrue);
      expect(MomoSmsIngestionRepository.isApprovedSender('MOMO'), isTrue);
      expect(
          MomoSmsIngestionRepository.isApprovedSender('MobileMoney'), isTrue);
    });

    test('rejects unknown senders', () {
      expect(
          MomoSmsIngestionRepository.isApprovedSender('Airtel Money'), isFalse);
      expect(MomoSmsIngestionRepository.isApprovedSender('+250781234567'),
          isFalse);
      expect(MomoSmsIngestionRepository.isApprovedSender(''), isFalse);
      expect(MomoSmsIngestionRepository.isApprovedSender(null), isFalse);
    });

    test('body detection recognizes MoMo transaction patterns', () {
      expect(
        MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
          'You have received 5,000 RWF from Jean. TxID: 12345678. '
          'New balance: 10,000 RWF.',
        ),
        isTrue,
      );
    });

    test('body detection rejects non-financial messages', () {
      expect(
        MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
          'Welcome to MTN. Enjoy our services!',
        ),
        isFalse,
      );
    });

    test('captureFromDeviceMessage returns null for unknown sender', () {
      final result = MomoSmsIngestionRepository.captureFromDeviceMessage(
        sender: 'Unknown',
        body: 'Some random SMS',
      );
      expect(result, isNull);
    });

    test('captureFromDeviceMessage creates capture for valid SMS', () {
      final result = MomoSmsIngestionRepository.captureFromDeviceMessage(
        sender: 'MTN MoMo',
        body: 'You have received 5000 RWF',
        timestampMillis: DateTime.utc(2026, 4, 15).millisecondsSinceEpoch,
      );

      expect(result, isNotNull);
      expect(result!.sender, 'MTN MoMo');
      expect(result.body, 'You have received 5000 RWF');
      expect(result.deviceMessageKey, isNotEmpty);
    });

    test('buildDeviceMessageKey is deterministic', () {
      final now = DateTime.utc(2026, 4, 15);
      final key1 = MomoSmsIngestionRepository.buildDeviceMessageKey(
        sender: 'MTN MoMo',
        body: 'Test',
        receivedAt: now,
      );
      final key2 = MomoSmsIngestionRepository.buildDeviceMessageKey(
        sender: 'MTN MoMo',
        body: 'Test',
        receivedAt: now,
      );
      expect(key1, equals(key2));
    });

    test('buildDeviceMessageKey differs for different body', () {
      final now = DateTime.utc(2026, 4, 15);
      final key1 = MomoSmsIngestionRepository.buildDeviceMessageKey(
        sender: 'MTN MoMo',
        body: 'Message A',
        receivedAt: now,
      );
      final key2 = MomoSmsIngestionRepository.buildDeviceMessageKey(
        sender: 'MTN MoMo',
        body: 'Message B',
        receivedAt: now,
      );
      expect(key1, isNot(equals(key2)));
    });
  });
}

// ─── Fake repositories for drain testing ─── //

class _SuccessfulRepo extends MomoSmsIngestionRepository {
  _SuccessfulRepo() : super(client: _dummyClient);

  @override
  Future<MomoSmsIngestionResult?> ingestCapture({
    required MomoSmsCapture capture,
    String? userId,
  }) async {
    return MomoSmsIngestionResult(
      rawSmsId: 'raw-${capture.deviceMessageKey}',
      inserted: true,
      parseQueued: true,
    );
  }
}

class _PartiallyFailingRepo extends MomoSmsIngestionRepository {
  _PartiallyFailingRepo({required this.failKeys}) : super(client: _dummyClient);

  final Set<String> failKeys;

  @override
  Future<MomoSmsIngestionResult?> ingestCapture({
    required MomoSmsCapture capture,
    String? userId,
  }) async {
    if (failKeys.contains(capture.deviceMessageKey)) {
      throw Exception('Simulated ingestion failure');
    }
    return MomoSmsIngestionResult(
      rawSmsId: 'raw-${capture.deviceMessageKey}',
      inserted: true,
      parseQueued: true,
    );
  }
}

// Minimal dummy — never actually used (overridden methods don't call super).
final _dummyClient = SupabaseClient('https://example.supabase.co', 'anon');
