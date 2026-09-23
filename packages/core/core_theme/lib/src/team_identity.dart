import 'team_assets.g.dart';

export 'team_assets.g.dart' show TeamAsset, teamAssets;

String _teamKey(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

TeamAsset? teamAssetFor(String name, {String? crestUrl}) {
  final index =
      teamAssetAliases[_teamKey(name)] ??
      (crestUrl == null ? null : teamAssetAliases[_teamKey(crestUrl)]);
  return index == null ? null : teamAssets[index];
}

/// Presentation only: stored team names and match-side ordering stay intact.
String teamInitials(String name) {
  final registered = teamAssetFor(name);
  if (registered != null) return registered.initials;
  final words = name
      .trim()
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '—';
  final value = words.length == 1
      ? words.first
      : words.map((word) => word[0]).join();
  return value.substring(0, value.length.clamp(0, 4)).toUpperCase();
}

String fixtureInitials(String first, String second) =>
    '${teamInitials(first)} · ${teamInitials(second)}';
