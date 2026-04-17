// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

bool _designFontsLoaded = false;

Future<void> loadDesignFonts() async {
  if (_designFontsLoaded) {
    return;
  }

  final cacheEntries = await _loadFontCacheEntries();
  final applicationSupportDirectory = Directory(
    '${Directory.systemTemp.path}/africlub_google_fonts_test_cache',
  );
  await applicationSupportDirectory.create(recursive: true);
  PathProviderPlatform.instance = _DesignFontPathProvider(
    applicationSupportDirectory.path,
  );

  for (final entry in cacheEntries) {
    final file = File(
      '${applicationSupportDirectory.path}/${entry.cacheName}_${entry.fileHash}.ttf',
    );
    if (!file.existsSync()) {
      await file.writeAsBytes(entry.bytes, flush: true);
    }
  }

  await Future.wait(cacheEntries.map(_preloadFont));

  GoogleFonts.config.allowRuntimeFetching = false;

  _designFontsLoaded = true;
}

Future<List<_FontCacheEntry>> _loadFontCacheEntries() async {
  const manifest = <_FontCacheDescriptor>[
    _FontCacheDescriptor(
      cacheName: 'SpaceGrotesk_600',
      fileHash:
          '7aa897b1b290336dbf3178a7baa371dc447a19eeb349689c4ed1d929c4c4eca1',
      localCandidates: <String>[
        'SpaceGrotesk-SemiBold.ttf',
        'BarlowCondensed-SemiBold.ttf',
      ],
    ),
    _FontCacheDescriptor(
      cacheName: 'SpaceGrotesk_700',
      fileHash:
          '17d1b2f12f3a57623a66c38fda77109af0c721123e2140577f3293509bf1dc7a',
      localCandidates: <String>[
        'SpaceGrotesk-Bold.ttf',
        'BarlowCondensed-Bold.ttf',
      ],
    ),
    _FontCacheDescriptor(
      cacheName: 'Manrope_regular',
      fileHash:
          '1ddeeeff9fe3d294f709f2239557278930f56dab89db1fe535dc5c35cd67e0ee',
      localCandidates: <String>['Manrope-Regular.ttf', 'Inter-Regular.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Manrope_500',
      fileHash:
          'acdd0ae608f0e024750c98bb1c4e76c13e31ad2b848eb8da7fcd783c051abafa',
      localCandidates: <String>['Manrope-Medium.ttf', 'Inter-Medium.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Manrope_600',
      fileHash:
          '8791ca409cf36b8b2842e40b6b1cd5b42cca064b4fdf24e30f5611536793429d',
      localCandidates: <String>['Manrope-SemiBold.ttf', 'Inter-SemiBold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Manrope_700',
      fileHash:
          'e7793683898d8a0e4c97ec50116fc021d053f2f72113982076a50a9048f101b5',
      localCandidates: <String>['Manrope-Bold.ttf', 'Inter-Bold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Manrope_800',
      fileHash:
          '6b753fbbbefcdfd17909197147c199d6ebc1cd79742e853bc1e732bc9f49831b',
      localCandidates: <String>['Manrope-ExtraBold.ttf', 'Manrope-Bold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_regular',
      fileHash:
          'ecdb53099b1a68cd24c6900ea5beeafec81bd3c8cb9d0f3c51b9986583ba3982',
      localCandidates: <String>['Inter-Regular.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_500',
      fileHash:
          '492dec3bc33255f9d81bd5fb18704ad72f96f9b9318e4171bc9f9be9dd4bf44b',
      localCandidates: <String>['Inter-Medium.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_500normal',
      fileHash:
          '492dec3bc33255f9d81bd5fb18704ad72f96f9b9318e4171bc9f9be9dd4bf44b',
      localCandidates: <String>['Inter-Medium.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_600',
      fileHash:
          'd7ba633bab7f40576e539a7e934a1301d7618dceea59c743de477c2c493462fc',
      localCandidates: <String>['Inter-SemiBold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_600normal',
      fileHash:
          'd7ba633bab7f40576e539a7e934a1301d7618dceea59c743de477c2c493462fc',
      localCandidates: <String>['Inter-SemiBold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_700',
      fileHash:
          'b7e339223d56e8c4210c86f1ba87b3d43d6c47e03956ea56f0a7a938ae61b2a3',
      localCandidates: <String>['Inter-Bold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_700normal',
      fileHash:
          '76121a34a606cc8a0e1ef5a47d2b9ba9678c41f5c852d63eb28f62069373bfad',
      localCandidates: <String>['Inter-Bold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_800normal',
      fileHash:
          '6af943899936fd3fd15a5889db4a384cec311c9bfe33d74bcfd3e0ae56f1b1d1',
      localCandidates: <String>['Inter-Bold.ttf'],
    ),
    _FontCacheDescriptor(
      cacheName: 'Inter_900normal',
      fileHash:
          'd892b18d080d1200aa41ea8851da84dd8c24c33843d491fa034ac57b16f22973',
      localCandidates: <String>['Inter-Bold.ttf'],
    ),
  ];

  final cacheEntries = <_FontCacheEntry>[];
  for (final descriptor in manifest) {
    final file = _resolveFontFile(descriptor.localCandidates);
    cacheEntries.add(
      _FontCacheEntry(
        cacheName: descriptor.cacheName,
        fileHash: descriptor.fileHash,
        bytes: await file.readAsBytes(),
      ),
    );
  }
  return cacheEntries;
}

File _resolveFontFile(List<String> names) {
  for (final root in _resolveFontRoots()) {
    for (final name in names) {
      final file = File('${root.path}/$name');
      if (file.existsSync()) {
        return file;
      }
    }
  }

  throw FileSystemException('Unable to locate design fonts', names.join(', '));
}

List<Directory> _resolveFontRoots() {
  var cursor = Directory.current.absolute;
  final roots = <Directory>[];
  final seen = <String>{};

  void addRoot(Directory directory) {
    final path = directory.absolute.path;
    if (!directory.existsSync() || !seen.add(path)) {
      return;
    }
    roots.add(directory);
  }

  while (true) {
    final featuresRoot = Directory('${cursor.path}/packages/features');
    if (featuresRoot.existsSync()) {
      for (final entity in featuresRoot.listSync(followLinks: false)) {
        if (entity is! Directory) {
          continue;
        }
        addRoot(Directory('${entity.path}/test/fonts'));
        addRoot(Directory('${entity.path}/build/unit_test_assets/test/fonts'));
      }
    }

    addRoot(Directory('${cursor.path}/apps/rayon_sports/google_fonts'));

    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }

  if (roots.isEmpty) {
    throw FileSystemException(
      'Unable to locate design font roots from current directory',
      Directory.current.path,
    );
  }

  return roots;
}

Future<void> _preloadFont(_FontCacheEntry entry) async {
  final loader = FontLoader(entry.cacheName);
  loader.addFont(Future<ByteData>.value(ByteData.sublistView(entry.bytes)));
  await loader.load();
}

class _FontCacheDescriptor {
  const _FontCacheDescriptor({
    required this.cacheName,
    required this.fileHash,
    required this.localCandidates,
  });

  final String cacheName;
  final String fileHash;
  final List<String> localCandidates;
}

class _FontCacheEntry {
  const _FontCacheEntry({
    required this.cacheName,
    required this.fileHash,
    required this.bytes,
  });

  final String cacheName;
  final String fileHash;
  final Uint8List bytes;
}

class _DesignFontPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _DesignFontPathProvider(this.applicationSupportPath);

  final String applicationSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => applicationSupportPath;

  @override
  Future<String?> getTemporaryPath() async => applicationSupportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => applicationSupportPath;

  @override
  Future<String?> getApplicationCachePath() async => applicationSupportPath;

  @override
  Future<String?> getLibraryPath() async => applicationSupportPath;

  @override
  Future<String?> getExternalStoragePath() async => null;

  @override
  Future<List<String>?> getExternalCachePaths() async => null;

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async => null;

  @override
  Future<String?> getDownloadsPath() async => applicationSupportPath;
}
