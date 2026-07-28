import 'dart:async';

import 'package:flutter/material.dart';

enum DiscoveryCategory { all, supporters, fixtures, commerce, services }

extension DiscoveryCategoryLabel on DiscoveryCategory {
  String get label => switch (this) {
    DiscoveryCategory.all => 'All',
    DiscoveryCategory.supporters => 'Supporters',
    DiscoveryCategory.fixtures => 'Fixtures',
    DiscoveryCategory.commerce => 'Tickets & shop',
    DiscoveryCategory.services => 'Services',
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
  });

  final String text;
  final DiscoveryCategory category;

  @override
  bool operator ==(Object other) {
    return other is DiscoverySearchQuery &&
        other.text == text &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(text, category);
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
