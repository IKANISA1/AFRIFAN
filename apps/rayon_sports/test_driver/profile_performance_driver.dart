import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  final outputDirectory =
      Platform.environment['AFRICLUB_PERFORMANCE_OUTPUT_DIR'] ??
      'build/profile-performance';
  return integrationDriver(
    responseDataCallback: (data) => writeResponseData(
      data,
      testOutputFilename: 'flutter-profile-performance',
      destinationDirectory: outputDirectory,
    ),
  );
}
