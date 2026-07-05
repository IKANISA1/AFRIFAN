import 'dart:convert';

class FetRewardOption {
  const FetRewardOption({
    this.id = '',
    this.slug = '',
    required this.reward,
    required this.cost,
    required this.category,
    required this.notes,
    this.costFet = 0,
    this.emoji,
    this.isActive = true,
  });

  factory FetRewardOption.fromJson(Map<String, dynamic> json) {
    final costFet =
        (json['cost_fet'] as num?)?.toInt() ??
        int.tryParse(
          (json['cost_label']?.toString() ?? json['cost']?.toString() ?? '')
              .replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    return FetRewardOption(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      reward: json['reward']?.toString() ?? json['title']?.toString() ?? '',
      cost:
          json['cost_label']?.toString() ??
          json['cost']?.toString() ??
          (costFet > 0 ? '$costFet FET' : ''),
      category: json['category']?.toString() ?? '',
      notes:
          json['notes']?.toString() ??
          json['description']?.toString() ??
          json['redemption_note']?.toString() ??
          '',
      costFet: costFet,
      emoji: json['emoji']?.toString(),
      isActive: json['is_active'] != false,
    );
  }

  final String id;
  final String slug;
  final String reward;
  final String cost;
  final String category;
  final String notes;
  final int costFet;
  final String? emoji;
  final bool isActive;
}

abstract final class RewardStoreContent {
  /// Backward-compatible parser name retained for older tests/callers.
  static List<FetRewardOption> parseOptions(String payload) {
    return parseCatalogPayload(payload);
  }

  static List<FetRewardOption> parseCatalogPayload(String payload) {
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
}
