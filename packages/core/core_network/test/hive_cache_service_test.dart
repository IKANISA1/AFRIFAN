import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('africlub_cache_test_');
    Hive.init(tempDir.path);
    await HiveCacheService.resetForTest(deleteBox: true);
    await HiveCacheService.initialize();
  });

  tearDown(() async {
    await HiveCacheService.resetForTest(deleteBox: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('stores and retrieves cached json', () async {
    await HiveCacheService.putJson('fixtures', <String, dynamic>{'count': 3});

    final cached = HiveCacheService.getJson<Map>('fixtures');

    expect(cached, isNotNull);
    expect(cached?['count'], equals(3));
  });

  test('returns stale payload when allowExpired is true', () async {
    await HiveCacheService.putJson('stats', <String, dynamic>{
      'wins': 2,
    }, ttl: const Duration(milliseconds: 1));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(HiveCacheService.getJson<Map>('stats'), isNull);

    final stale = HiveCacheService.getJson<Map>('stats', allowExpired: true);
    expect(stale, isNotNull);
    expect(stale?['wins'], equals(2));
  });
}
