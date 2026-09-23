import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves synthetic native journey frames; saving is not a fidelity verdict.
Future<void> main() async {
  final output = Directory(
    Platform.environment['AFRICLUB_REFERENCE_OUTPUT_DIR'] ??
        'build/native-reference',
  );
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      await File(
        '${output.path}/$safeName.png',
      ).writeAsBytes(bytes, flush: true);
      return bytes.isNotEmpty;
    },
    responseDataCallback: (data) => writeResponseData(
      data,
      testOutputFilename: 'native-journey',
      destinationDirectory: output.path,
    ),
    writeResponseOnFailure: true,
  );
}
