import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> arguments) {
  final root = _repoRoot();
  final outputDirectory = Directory(
    arguments.isEmpty
        ? '${root.path}/output/implementation_goal_20260724/status_accessibility_inventory'
        : arguments.first,
  )..createSync(recursive: true);
  final files = _productionSourceFiles(root);
  final occurrences = <Map<String, Object?>>[];
  final componentCounts = <String, int>{};
  final colorPattern = RegExp(
    r'ColorTokens\.(success|warning|error|info)|'
    r'\bcolors\.(success|warning|danger|info)\b|'
    r'--admin-(success|warning|danger|info)',
  );
  final componentPatterns = <String, RegExp>{
    'AfriStatusChip': RegExp(r'\bAfriStatusChip\s*\('),
    'AfriStateBanner': RegExp(r'\bAfriStateBanner\s*\('),
    'AfriStateView': RegExp(
      r'\bAfriStateView\.(loading|empty|offline|error|success)\s*\(',
    ),
    'AfriInfoChip': RegExp(r'\bAfriInfoChip\s*\('),
    'AdminStatusBadge': RegExp(r'<AdminStatusBadge\b'),
  };

  for (final file in files) {
    final relative = _relative(root, file);
    final lines = file.readAsLinesSync();
    final fileContent = lines.join('\n');
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final entry in componentPatterns.entries) {
        final count = entry.value.allMatches(line).length;
        if (count == 0) continue;
        componentCounts.update(
          entry.key,
          (value) => value + count,
          ifAbsent: () => count,
        );
      }
      if (!colorPattern.hasMatch(line)) continue;

      final start = math.max(0, index - 48);
      final end = math.min(lines.length, index + 49);
      final context = lines.sublist(start, end).join('\n');
      final channels = <String>[
        if (RegExp(
          r'\b(Text|RichText)\s*\(|\b(label|title|subtitle|message)\s*:|'
          r'<(button|span|p|h[1-6]|dt|dd)\b|'
          r'Afri(StatusChip|StateBanner|StateView|InfoChip)|AdminStatusBadge',
        ).hasMatch(context))
          'visible_text',
        if (RegExp(r'\bIcon\s*\(|\bicon\s*:|AfriIcons\.').hasMatch(context))
          'icon',
        if (RegExp(
          r'\bSemantics\s*\(|semanticsLabel|aria-label|'
          r'role\s*=\s*["\x27](status|alert)["\x27]',
        ).hasMatch(context))
          'semantics',
        if (RegExp(r'_statusColor').hasMatch(context) &&
            RegExp(r'_statusLabel').hasMatch(fileContent))
          'companion_visible_status_label',
        if (RegExp(
          r'\bborder(?:Radius)?\s*:|BorderTokens\.|border-color',
        ).hasMatch(context))
          'shape_or_boundary',
      ];
      final isSharedContract =
          relative.contains('packages/core/core_theme/') ||
          relative.endsWith('apps/rayon_sports/web/src/ui-kit/theme.css') ||
          relative.endsWith('admin-status-badge.tsx');
      final isDecorative = relative.endsWith('confetti_overlay.dart');
      final disposition = isDecorative
          ? 'decorative_non_status'
          : isSharedContract
          ? 'shared_contract'
          : channels.isNotEmpty
          ? 'paired_non_color_channel'
          : 'review_required';

      occurrences.add(<String, Object?>{
        'path': relative,
        'line': index + 1,
        'source': line.trim(),
        'channels': channels,
        'disposition': disposition,
      });
    }
  }

  occurrences.sort((a, b) {
    final path = (a['path'] as String).compareTo(b['path'] as String);
    return path != 0 ? path : (a['line'] as int).compareTo(b['line'] as int);
  });
  final reviewRequired = occurrences
      .where((entry) => entry['disposition'] == 'review_required')
      .length;
  final simulations = _simulations(root);
  final result = <String, Object?>{
    'schema_version': '1.0',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'workspace': root.path,
    'scope': <String>[
      'packages/**/lib/**/*.dart',
      'apps/rayon_sports/web/src/**/*.{ts,tsx,css}',
    ],
    'summary': <String, Object?>{
      'production_files_scanned': files.length,
      'semantic_color_occurrences': occurrences.length,
      'status_component_occurrences': componentCounts.values.fold<int>(
        0,
        (sum, value) => sum + value,
      ),
      'review_required': reviewRequired,
      'contract_complete': reviewRequired == 0,
    },
    'component_counts': componentCounts,
    'color_vision_simulations': simulations,
    'occurrences': occurrences,
  };

  final jsonFile = File('${outputDirectory.path}/status-inventory.json');
  jsonFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result)}\n',
  );
  final reportFile = File('${outputDirectory.path}/status-inventory.md');
  reportFile.writeAsStringSync(_markdown(result));

  stdout.writeln('Status inventory JSON: ${jsonFile.path}');
  stdout.writeln('Status inventory report: ${reportFile.path}');
  stdout.writeln(
    'Scanned ${files.length} files; ${occurrences.length} semantic-color '
    'occurrences; $reviewRequired require review.',
  );
  if (reviewRequired != 0) {
    stderr.writeln(
      '$reviewRequired semantic-color occurrences require explicit review.',
    );
    exit(2);
  }
}

Directory _repoRoot() {
  var candidate = Directory.current.absolute;
  while (true) {
    if (Directory('${candidate.path}/packages').existsSync() &&
        Directory('${candidate.path}/apps').existsSync()) {
      return candidate;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError('Could not locate the AFRICLUB repository root.');
    }
    candidate = parent;
  }
}

List<File> _productionSourceFiles(Directory root) {
  final roots = <Directory>[
    Directory('${root.path}/packages'),
    Directory('${root.path}/apps/rayon_sports/web/src'),
  ];
  final files = <File>[];
  for (final sourceRoot in roots) {
    if (!sourceRoot.existsSync()) continue;
    for (final entity in sourceRoot.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final path = entity.path;
      final isWeb =
          path.endsWith('.ts') ||
          path.endsWith('.tsx') ||
          path.endsWith('.css');
      final isDart = path.endsWith('.dart') && path.contains('/lib/');
      if ((!isWeb && !isDart) ||
          path.contains('/test/') ||
          path.contains('.test.') ||
          path.endsWith('.g.dart')) {
        continue;
      }
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String _relative(Directory root, File file) =>
    file.path.substring(root.path.length + 1);

List<Map<String, Object?>> _simulations(Directory root) {
  final tokenFile = File(
    '${root.path}/packages/core/core_theme/lib/src/tokens/color_tokens.dart',
  ).readAsStringSync();
  final tokenPattern = RegExp(
    r'static const Color _(dark|light)(Success|Warning|Error|Info) = '
    r'Color\(0xFF([0-9A-Fa-f]{6})\);',
  );
  final tokens = <String, int>{
    for (final match in tokenPattern.allMatches(tokenFile))
      '${match.group(1)}_${match.group(2)!.toLowerCase()}': int.parse(
        match.group(3)!,
        radix: 16,
      ),
  };
  if (tokens.length != 8) {
    throw StateError(
      'Expected eight status palette tokens, found ${tokens.length}.',
    );
  }
  const matrices = <String, List<double>>{
    'protanopia': <double>[
      0.56667,
      0.43333,
      0,
      0.55833,
      0.44167,
      0,
      0,
      0.24167,
      0.75833,
    ],
    'deuteranopia': <double>[0.625, 0.375, 0, 0.7, 0.3, 0, 0, 0.3, 0.7],
    'tritanopia': <double>[0.95, 0.05, 0, 0, 0.43333, 0.56667, 0, 0.475, 0.525],
  };
  return <Map<String, Object?>>[
    for (final palette in tokens.entries)
      <String, Object?>{
        'token': palette.key,
        'source_hex': _hex(palette.value),
        for (final matrix in matrices.entries)
          matrix.key: _hex(_simulate(palette.value, matrix.value)),
        'non_color_contract': <String>[
          'visible_text',
          'icon_or_boundary_where_applicable',
          'semantic_tone',
        ],
      },
  ];
}

int _simulate(int rgb, List<double> matrix) {
  final red = (rgb >> 16) & 0xff;
  final green = (rgb >> 8) & 0xff;
  final blue = rgb & 0xff;
  int channel(int offset) =>
      (matrix[offset] * red +
              matrix[offset + 1] * green +
              matrix[offset + 2] * blue)
          .round()
          .clamp(0, 255);
  return (channel(0) << 16) | (channel(3) << 8) | channel(6);
}

String _hex(int rgb) =>
    '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _markdown(Map<String, Object?> result) {
  final summary = result['summary']! as Map<String, Object?>;
  final counts = result['component_counts']! as Map<String, int>;
  final simulations =
      result['color_vision_simulations']! as List<Map<String, Object?>>;
  final occurrences = result['occurrences']! as List<Map<String, Object?>>;
  final buffer = StringBuffer()
    ..writeln('# Color-independent status inventory')
    ..writeln()
    ..writeln(
      'Generated from the current production source. This is an '
      'automated equivalent review: simulated palette output is recorded, '
      'while meaning is required to survive through text, icon, boundary, '
      'or semantics rather than hue separation.',
    )
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..writeln(
      '- Production files scanned: '
      '${summary['production_files_scanned']}',
    )
    ..writeln(
      '- Semantic-color occurrences: '
      '${summary['semantic_color_occurrences']}',
    )
    ..writeln(
      '- Status-component occurrences: '
      '${summary['status_component_occurrences']}',
    )
    ..writeln('- Requiring review: ${summary['review_required']}')
    ..writeln('- Contract complete: ${summary['contract_complete']}')
    ..writeln()
    ..writeln('## Status components')
    ..writeln()
    ..writeln('| Component | Production occurrences |')
    ..writeln('| --- | ---: |');
  for (final entry
      in counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    buffer.writeln('| `${entry.key}` | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('## Color-vision simulations')
    ..writeln()
    ..writeln('| Token | Source | Protanopia | Deuteranopia | Tritanopia |')
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final row in simulations) {
    buffer.writeln(
      '| `${row['token']}` | ${row['source_hex']} | ${row['protanopia']} | '
      '${row['deuteranopia']} | ${row['tritanopia']} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Audited semantic-color occurrences')
    ..writeln()
    ..writeln('| Source | Disposition | Non-color channels |')
    ..writeln('| --- | --- | --- |');
  for (final row in occurrences) {
    final channels = (row['channels']! as List<String>).join(', ');
    buffer.writeln(
      '| `${row['path']}:${row['line']}` | ${row['disposition']} | '
      '${channels.isEmpty ? 'not applicable' : channels} |',
    );
  }
  return buffer.toString();
}
