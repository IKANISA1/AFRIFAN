import 'dart:convert';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feat_shop/src/shop_checkout_recovery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'shop_checkout_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual journal encrypts durable original attempt and reopens under original scope',
    () async {
      final directory = await Directory.systemTemp.createTemp('shop-journal-');
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
      final journal = HiveShopCheckoutJournal();
      final attempt = ShopCheckoutAttempt(
        userId: checkoutUserId,
        clubId: '24',
        reference: checkoutReference,
        items: [checkoutItem()],
        address: '12 Amahoro Avenue',
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
      final file = File('${directory.path}/africlub_shop_checkout_v1.hive');
      final bytes = latin1.decode(await file.readAsBytes());
      expect(bytes, isNot(contains('12 Amahoro Avenue')));
      expect(bytes, isNot(contains(checkoutReference)));
      await Hive.close();
      HiveEncryptionService.resetForTest();
      await HiveEncryptionService.initialize();
      final relaunched = HiveShopCheckoutJournal();
      final original = ShopCheckoutAttempt.decode(
        await relaunched.read(attempt.scope),
        checkoutUserId,
        '24',
      );
      expect(original!.reference, checkoutReference);
      expect(original.address, attempt.address);
      expect(
        await relaunched.read('africlub-shop-v1:24:other-account'),
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
