import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

enum BioPayNfcStatus { available, disabled, notSupported }

class BioPayNfcReadResult {
  const BioPayNfcReadResult({this.uri, this.rawText});

  final Uri? uri;
  final String? rawText;

  bool get hasPayload => uri != null || (rawText?.trim().isNotEmpty ?? false);
}

class BioPayNfcService {
  static bool get canWrite => !kIsWeb && Platform.isAndroid;

  static Future<BioPayNfcStatus> checkAvailability() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      return switch (availability) {
        NFCAvailability.available => BioPayNfcStatus.available,
        NFCAvailability.disabled => BioPayNfcStatus.disabled,
        NFCAvailability.not_supported => BioPayNfcStatus.notSupported,
      };
    } catch (_) {
      return BioPayNfcStatus.notSupported;
    }
  }

  static Future<BioPayNfcReadResult> readTag() async {
    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 30),
        iosAlertMessage: 'Hold near a BioPay payment request',
      );

      final records = await FlutterNfcKit.readNDEFRecords();
      String? rawText;
      Uri? uri;

      for (final record in records) {
        if (record is ndef.UriRecord) {
          rawText = record.uriString;
          uri = rawText == null ? null : Uri.tryParse(rawText);
          if (uri != null) break;
        } else if (record is ndef.TextRecord) {
          rawText = record.text;
          if (rawText != null) {
            uri = Uri.tryParse(rawText);
            if (uri != null) break;
          }
        }
      }

      await FlutterNfcKit.finish(iosAlertMessage: 'BioPay NFC request read');
      return BioPayNfcReadResult(uri: uri, rawText: rawText);
    } catch (error) {
      try {
        await FlutterNfcKit.finish(iosErrorMessage: 'BioPay NFC scan failed');
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> writeUri(Uri uri) async {
    if (!canWrite) {
      throw UnsupportedError('BioPay NFC write is only supported on Android.');
    }

    try {
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 30),
      );
      if (tag.ndefWritable != true) {
        await FlutterNfcKit.finish();
        throw StateError('This NFC target is not writable.');
      }

      await FlutterNfcKit.writeNDEFRecords([ndef.UriRecord.fromUri(uri)]);
      await FlutterNfcKit.finish();
    } catch (error) {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> cancelSession({String? reason}) async {
    try {
      await FlutterNfcKit.finish(
        iosErrorMessage: reason ?? 'BioPay NFC session cancelled',
      ).timeout(const Duration(milliseconds: 400));
    } catch (_) {}
  }
}
