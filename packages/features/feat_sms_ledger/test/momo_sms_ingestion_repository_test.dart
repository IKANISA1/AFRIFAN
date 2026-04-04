import 'package:feat_sms_ledger/src/repositories/momo_sms_ingestion_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MomoSmsIngestionRepository', () {
    test('isApprovedSender accepts whitelisted senders in various cases', () {
      expect(MomoSmsIngestionRepository.isApprovedSender('MTN MoMo'), true);
      expect(MomoSmsIngestionRepository.isApprovedSender('mtn momo'), true);
      expect(MomoSmsIngestionRepository.isApprovedSender(' M-Money '), true);
      expect(
          MomoSmsIngestionRepository.isApprovedSender('M-Money Alerts'), true);
      expect(MomoSmsIngestionRepository.isApprovedSender('Mobile Money'), true);
      expect(MomoSmsIngestionRepository.isApprovedSender('MoMo'), true);
      expect(MomoSmsIngestionRepository.isApprovedSender('MTN MOMO'), true);
      expect(
          MomoSmsIngestionRepository.isApprovedSender('MTN MoMo Rwanda'), true);
    });

    test('isApprovedSender rejects random senders', () {
      expect(
          MomoSmsIngestionRepository.isApprovedSender('+250781234567'), false);
      expect(MomoSmsIngestionRepository.isApprovedSender('Airtel'), false);
      expect(MomoSmsIngestionRepository.isApprovedSender('Bank'), false);
      expect(MomoSmsIngestionRepository.isApprovedSender(''), false);
      expect(MomoSmsIngestionRepository.isApprovedSender(null), false);
    });

    test('looksLikePotentialMomoTransactionalBody identifies valid texts', () {
      const text1 =
          'You have received 5,000 RWF from John Doe. New balance is 10,000 RWF. TxId: 12345';
      expect(
          MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
              text1),
          true);

      const text2 =
          'Transferred 1,000 Frw to Bank. Fee was 100 Frw. Tax: 10 Frw. Balance: 50,000 Frw. Financial Transaction Id: 9876';
      expect(
          MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
              text2),
          true);

      const text3 =
          'Payment of 2500 RWF to Merchant successful. New balance: 400 RWF.';
      // No brand signal and no TxId → should be rejected
      expect(
          MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
              text3),
          false);

      const text4 =
          'Mobile money payment of 2500 RWF to Merchant successful. New balance: 400 RWF.';
      expect(
          MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
              text4),
          true);
    });

    test('looksLikePotentialMomoTransactionalBody rejects standard texts', () {
      const text1 = 'Hello, how are you today?';
      expect(
          MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
              text1),
          false);

      const text2 = 'Please send me the RWF 1000 today.';
      expect(
          MomoSmsIngestionRepository.looksLikePotentialMomoTransactionalBody(
              text2),
          false);
    });

    test('senderDriftTelemetry detects anomalous senders with MoMo body', () {
      final telemetry = MomoSmsIngestionRepository.senderDriftTelemetry(
        sender: '+250788111222',
        body:
            'You have received 5,000 RWF from John. New balance: 10,000 RWF. TxId: 123',
      );

      expect(telemetry, isNotNull);
      expect(telemetry!['sender_kind'], 'msisdn');
      expect(telemetry['has_tx_reference'], true);
      expect(telemetry['contains_rwf'], true);
      expect(telemetry['signal_count'], greaterThanOrEqualTo(2));
    });

    test('senderDriftTelemetry returns null for normal cases', () {
      // Valid sender
      final telemetry1 = MomoSmsIngestionRepository.senderDriftTelemetry(
        sender: 'MoMo',
        body:
            'You have received 5,000 RWF from John. New balance: 10,000 RWF. TxId: 123',
      );
      expect(telemetry1, isNull);

      // Invalid sender, invalid body
      final telemetry2 = MomoSmsIngestionRepository.senderDriftTelemetry(
        sender: 'Airtel',
        body: 'Hello',
      );
      expect(telemetry2, isNull);
    });

    test('captureFromDeviceMessage constructs capture correctly', () {
      final timestamp = DateTime.utc(2025, 1, 1).millisecondsSinceEpoch;
      final capture = MomoSmsIngestionRepository.captureFromDeviceMessage(
        sender: ' MTN MoMo ', // will be trimmed
        body: '   You received 1,000 RWF. TxId: 444 \n ',
        timestampMillis: timestamp,
        ingestionSource: 'test',
        countryCode: 'RW',
      );

      expect(capture, isNotNull);
      expect(capture!.sender, 'MTN MoMo');
      expect(capture.body, 'You received 1,000 RWF. TxId: 444');
      expect(capture.ingestionSource, 'test');
      expect(capture.countryCode, 'RW');
      expect(capture.deviceMessageKey, isNotEmpty);
    });

    test('captureFromDeviceMessage returns null for invalid sender', () {
      final capture = MomoSmsIngestionRepository.captureFromDeviceMessage(
        sender: 'Unknown',
        body: 'You received 1,000 RWF. TxId: 444',
      );
      expect(capture, isNull);
    });
  });
}
