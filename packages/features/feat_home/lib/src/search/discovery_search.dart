import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:flutter/material.dart';

enum DiscoveryCategory { all, supporters, fixtures, commerce, services }

extension DiscoveryCategoryLabel on DiscoveryCategory {
  String label(AfriLocalizations l10n) => switch (this) {
    DiscoveryCategory.all => l10n.searchCategoryAll,
    DiscoveryCategory.supporters => l10n.searchCategorySupporters,
    DiscoveryCategory.fixtures => l10n.searchCategoryFixtures,
    DiscoveryCategory.commerce => l10n.searchCategoryCommerce,
    DiscoveryCategory.services => l10n.searchCategoryServices,
  };
}

@immutable
class DiscoveryResult {
  const DiscoveryResult({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.destination,
    required this.icon,
    this.keywords = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final DiscoveryCategory category;
  final String destination;
  final IconData icon;
  final List<String> keywords;
}

@immutable
class DiscoverySearchQuery {
  const DiscoverySearchQuery({
    required this.text,
    this.category = DiscoveryCategory.all,
    this.localeName = 'en',
  });

  final String text;
  final DiscoveryCategory category;
  final String localeName;

  AfriLocalizations get l10n {
    final languageCode = localeName.split(RegExp('[-_]')).first;
    return lookupAfriLocalizations(Locale(languageCode));
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoverySearchQuery &&
        other.text == text &&
        other.category == category &&
        other.localeName == localeName;
  }

  @override
  int get hashCode => Object.hash(text, category, localeName);
}

@immutable
class DiscoverySearchResponse {
  const DiscoverySearchResponse({required this.results, this.offline = false});

  final List<DiscoveryResult> results;
  final bool offline;
}

enum DiscoverySearchFailureKind {
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

@immutable
class DiscoverySearchFailure implements Exception {
  const DiscoverySearchFailure(this.kind);

  final DiscoverySearchFailureKind kind;

  factory DiscoverySearchFailure.fromError(Object error) {
    if (error is DiscoverySearchFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const DiscoverySearchFailure(
        DiscoverySearchFailureKind.securityTimeout,
      );
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission denied') ||
        normalized.contains('row-level security') ||
        normalized.contains('not authorized') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden')) {
      return const DiscoverySearchFailure(
        DiscoverySearchFailureKind.permissionDenied,
      );
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed while') ||
        normalized.contains('stale')) {
      return const DiscoverySearchFailure(DiscoverySearchFailureKind.conflict);
    }
    return const DiscoverySearchFailure(DiscoverySearchFailureKind.unknown);
  }

  @override
  String toString() => 'DiscoverySearchFailure(${kind.name})';
}

abstract interface class DiscoverySearchRepository {
  Future<DiscoverySearchResponse> search(DiscoverySearchQuery query);
}
