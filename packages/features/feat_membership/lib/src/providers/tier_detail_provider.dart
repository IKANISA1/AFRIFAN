import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../official_membership_tiers.dart';
import 'membership_data_contract.dart';

enum TierDetailPhase { ready, syncing, degraded }

enum TierDetailFailureKind {
  offline,
  permissionDenied,
  conflict,
  securityTimeout,
  unknown,
}

class TierDetailFailure implements Exception {
  const TierDetailFailure(this.kind);

  final TierDetailFailureKind kind;

  static TierDetailFailure fromError(Object error) {
    if (error is TierDetailFailure) return error;
    if (error is TimeoutException) {
      return const TierDetailFailure(TierDetailFailureKind.securityTimeout);
    }
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('forbidden') ||
        normalized.contains('unauthorized') ||
        normalized.contains('row-level security') ||
        normalized.contains('rls')) {
      return const TierDetailFailure(TierDetailFailureKind.permissionDenied);
    }
    if (normalized.contains('conflict') ||
        normalized.contains('changed') ||
        normalized.contains('stale') ||
        normalized.contains('revision')) {
      return const TierDetailFailure(TierDetailFailureKind.conflict);
    }
    return const TierDetailFailure(TierDetailFailureKind.unknown);
  }

  @override
  String toString() => 'TierDetailFailure(${kind.name})';
}

class TierDetailData {
  const TierDetailData({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.priceLabel,
    required this.accessItems,
    required this.icon,
  });

  factory TierDetailData.fromPackage(Map<String, dynamic> json) {
    final normalized = normalizeMembershipSlug(
      json['tier']?.toString() ?? json['category_slug']?.toString(),
    );
    final fallback = TierDetailData.fromOfficialSlug(normalized);
    final benefits = parseMembershipBenefits(json['benefits']);
    final amount =
        (json['annual_price'] as num?)?.toInt() ??
        (json['price'] as num?)?.toInt() ??
        0;
    final billingPeriod = json['billing_period']?.toString() ?? 'annual';
    final accessItems = <String>[
      json['seating_access']?.toString() ?? '',
      json['match_access']?.toString() ?? '',
      json['source_label']?.toString() ?? '',
    ].where((entry) => entry.trim().isNotEmpty).toList(growable: false);

    return TierDetailData(
      slug: normalized,
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim().toUpperCase()
          : fallback.title,
      subtitle: json['subtitle']?.toString().trim() ?? fallback.subtitle,
      description:
          json['description']?.toString().trim() ?? fallback.description,
      benefits: benefits.isEmpty ? fallback.benefits : benefits,
      priceLabel: amount <= 0
          ? fallback.priceLabel
          : '${_formatAmount(amount)} RWF / $billingPeriod',
      accessItems: accessItems.isEmpty ? fallback.accessItems : accessItems,
      icon: fallback.icon,
    );
  }

  factory TierDetailData.fromOfficialSlug(String rawTier) {
    final normalized = normalizeMembershipSlug(rawTier);
    final package = officialMembershipPackage(normalized);
    if (package == null) {
      throw ArgumentError.value(rawTier, 'rawTier', 'Unknown membership tier');
    }
    final tier = officialMembershipTiers.firstWhere(
      (entry) => entry.slug == normalized,
    );
    return TierDetailData(
      slug: tier.slug,
      title: tier.name.toUpperCase(),
      subtitle: tier.track,
      description: tier.summary,
      benefits: tier.benefits,
      priceLabel: '${_formatAmount(tier.priceRwf)} RWF / ${tier.billingPeriod}',
      accessItems: <String>[
        if (tier.seatingAccess != null) tier.seatingAccess!,
        if (tier.matchAccess != null) tier.matchAccess!,
        'Official Rayon Sports membership category list',
      ],
      icon: switch (tier.slug) {
        'gold' => AfriIcons.rank,
        'silver' => AfriIcons.premium,
        'bronze' => AfriIcons.verified,
        _ => AfriIcons.membership,
      },
    );
  }

  static TierDetailData? officialOrNull(
    String rawTier, {
    bool includePaidDigitalBenefits = true,
  }) {
    final normalized = normalizeMembershipSlug(rawTier);
    final package = includePaidDigitalBenefits
        ? officialMembershipPackage(normalized)
        : storeReleaseMembershipPackage(normalized);
    if (package == null) return null;
    return includePaidDigitalBenefits
        ? TierDetailData.fromOfficialSlug(normalized)
        : TierDetailData.fromPackage(package);
  }

  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final String priceLabel;
  final List<String> accessItems;
  final IconData icon;
}

String _formatAmount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

class TierDetailState {
  const TierDetailState({
    this.data,
    this.phase = TierDetailPhase.ready,
    this.failure,
  });

  final TierDetailData? data;
  final TierDetailPhase phase;
  final TierDetailFailure? failure;

  TierDetailState copyWith({
    TierDetailData? data,
    TierDetailPhase? phase,
    TierDetailFailure? failure,
    bool clearFailure = false,
  }) {
    return TierDetailState(
      data: data ?? this.data,
      phase: phase ?? this.phase,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

abstract interface class TierDetailGateway {
  Future<TierDetailData?> load(String tierId);
}

class SupabaseTierDetailGateway implements TierDetailGateway {
  const SupabaseTierDetailGateway(
    this._client, {
    this.storeReleasePolicy = const StoreReleasePolicy(isEnforced: true),
  });

  final SupabaseClient _client;
  final StoreReleasePolicy storeReleasePolicy;

  @override
  Future<TierDetailData?> load(String tierId) async {
    final normalized = normalizeMembershipSlug(tierId);
    final scope = await ClubScopeResolver(client: _client).requireResolved();
    final response = await _client
        .from('membership_tiers')
        .select(MembershipReadProjection.tier)
        .eq('category_slug', normalized)
        .eq('club_id', scope.requiredClubId)
        .eq('active', true)
        .gt('annual_price', 0)
        .order('sort_order', ascending: true)
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isEmpty) return null;
    return TierDetailData.fromPackage(normalizeMembershipTierRow(rows.first));
  }
}

final tierDetailGatewayProvider = Provider<TierDetailGateway>(
  (ref) => SupabaseTierDetailGateway(
    ref.watch(supabaseClientProvider),
    storeReleasePolicy: ref.watch(storeReleasePolicyProvider),
  ),
);

final tierDetailLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

final tierDetailEnabledProvider = Provider<bool>((ref) => true);

final tierDetailProvider =
    StateNotifierProvider.family<
      TierDetailController,
      AsyncValue<TierDetailState>,
      String
    >((ref, tierId) {
      return TierDetailController(
        ref.watch(tierDetailGatewayProvider),
        tierId,
        loadTimeout: ref.watch(tierDetailLoadTimeoutProvider),
        storeReleasePolicy: ref.watch(storeReleasePolicyProvider),
      );
    });

class TierDetailController extends StateNotifier<AsyncValue<TierDetailState>> {
  TierDetailController(
    this._gateway,
    String tierId, {
    Duration loadTimeout = const Duration(seconds: 12),
    bool autoLoad = true,
    StoreReleasePolicy storeReleasePolicy = const StoreReleasePolicy(
      isEnforced: true,
    ),
  }) : _tierId = normalizeMembershipSlug(tierId),
       _loadTimeout = loadTimeout,
       super(
         AsyncValue.data(
           TierDetailState(
             data: TierDetailData.officialOrNull(
               tierId,
               includePaidDigitalBenefits:
                   storeReleasePolicy.allowsPaidDigitalMembership,
             ),
           ),
         ),
       ) {
    if (autoLoad) unawaited(refresh());
  }

  final TierDetailGateway _gateway;
  final String _tierId;
  final Duration _loadTimeout;
  bool _loading = false;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    final previous = state.valueOrNull;
    if (previous?.data != null) {
      state = AsyncValue.data(
        previous!.copyWith(phase: TierDetailPhase.syncing, clearFailure: true),
      );
    } else {
      state = const AsyncValue.loading();
    }

    try {
      if (!ConnectivityService.isOnline) {
        throw const TierDetailFailure(TierDetailFailureKind.offline);
      }
      final remote = await _gateway.load(_tierId).timeout(_loadTimeout);
      state = AsyncValue.data(TierDetailState(data: remote ?? previous?.data));
    } catch (error, stackTrace) {
      final failure = TierDetailFailure.fromError(error);
      state = previous?.data != null
          ? AsyncValue.data(
              previous!.copyWith(
                phase: TierDetailPhase.degraded,
                failure: failure,
              ),
            )
          : AsyncValue.error(failure, stackTrace);
    } finally {
      _loading = false;
    }
  }

  Future<void> connectionRestored() async {
    final current = state.valueOrNull;
    final stateError = state.error;
    final failure =
        current?.failure ??
        (stateError == null ? null : TierDetailFailure.fromError(stateError));
    if (failure?.kind != TierDetailFailureKind.offline) return;
    await refresh();
  }
}
