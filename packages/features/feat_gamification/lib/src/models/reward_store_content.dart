import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class FetRewardOption {
  const FetRewardOption({
    required this.reward,
    required this.cost,
    required this.category,
    required this.notes,
  });

  factory FetRewardOption.fromJson(Map<String, dynamic> json) {
    return FetRewardOption(
      reward: json['reward']?.toString() ?? '',
      cost: json['cost']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  final String reward;
  final String cost;
  final String category;
  final String notes;
}

abstract final class RewardStoreContent {
  static const String assetPath =
      'packages/feat_gamification/assets/reward_store_catalog.json';
  static const String _localAssetPath = 'assets/reward_store_catalog.json';

  static Future<List<FetRewardOption>> loadOptions() async {
    final payload = await _loadCatalogPayload();
    return parseOptions(payload);
  }

  static List<FetRewardOption> parseOptions(String payload) {
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) {
      return const <FetRewardOption>[];
    }

    final rawOptions = json['reward_options'];
    if (rawOptions is! List) {
      return const <FetRewardOption>[];
    }

    return rawOptions
        .whereType<Map>()
        .map(
          (entry) => FetRewardOption.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
  }

  static Future<String> _loadCatalogPayload() async {
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return rootBundle.loadString(_localAssetPath);
    }
  }
}
