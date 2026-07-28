import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final xcconfigPath = arguments.isEmpty
      ? 'ios/Flutter/Generated.xcconfig'
      : arguments.first;
  final flavorPath = arguments.length < 2
      ? 'assets/flavors/production.json'
      : arguments[1];
  final xcconfig = File(xcconfigPath);
  final flavor = File(flavorPath);
  if (!xcconfig.existsSync() || !flavor.existsSync()) {
    stderr.writeln('Missing generated xcconfig or canonical flavor JSON.');
    exitCode = 2;
    return;
  }

  final line = xcconfig
      .readAsLinesSync()
      .where((value) => value.startsWith('DART_DEFINES='))
      .firstOrNull;
  if (line == null || line.substring('DART_DEFINES='.length).trim().isEmpty) {
    stderr.writeln('Generated.xcconfig does not contain DART_DEFINES.');
    exitCode = 2;
    return;
  }

  final decoded = <String, String>{};
  for (final encoded in line.substring('DART_DEFINES='.length).split(',')) {
    try {
      final value = utf8.decode(
        base64.decode(base64.normalize(encoded.trim())),
      );
      final separator = value.indexOf('=');
      if (separator < 1) throw const FormatException('Expected KEY=VALUE');
      final key = value.substring(0, separator);
      if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(key)) {
        throw FormatException('Invalid key $key');
      }
      decoded[key] = value.substring(separator + 1);
    } on FormatException catch (error) {
      stderr.writeln('Malformed iOS DART_DEFINES entry: $error');
      exitCode = 1;
      return;
    }
  }

  final canonical =
      jsonDecode(flavor.readAsStringSync()) as Map<String, dynamic>;
  final missing = canonical.keys
      .where((key) => !decoded.containsKey(key))
      .toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Generated iOS defines are missing: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }
  stdout.writeln('Validated ${decoded.length} generated iOS Dart defines.');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
