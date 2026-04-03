import 'package:core_network/core_network.dart' hide supabaseClientProvider;
import 'package:core_network/core_network.dart'
    as core_network
    show supabaseClientProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/biopay_profile.dart';
import '../repositories/biopay_repository.dart';
import '../services/biopay_auth_gate_service.dart';
import '../services/biopay_cache_service.dart';
import '../services/biopay_embedding_service.dart';
import '../services/biopay_face_alignment_service.dart';
import '../services/biopay_face_detection_service.dart';
import '../services/biopay_nfc_hce_service.dart';
import '../services/biopay_nfc_service.dart';
import '../services/biopay_payment_handoff_service.dart';

// ─── Supabase ─────────────────────────────────────────────────

/// Supabase client provider — override per-app.
final supabaseClientProvider = core_network.supabaseClientProvider;

// ─── Repository ───────────────────────────────────────────────

/// BioPay repository provider.
final biopayRepositoryProvider = Provider<BiopayRepository>((ref) {
  return BiopayRepository(client: ref.watch(supabaseClientProvider));
});

// ─── Services ─────────────────────────────────────────────────

/// Payment handoff service.
final biopayPaymentHandoffServiceProvider =
    Provider<BiopayPaymentHandoffService>((ref) {
      return const BiopayPaymentHandoffService();
    });

/// Auth gate service.
final biopayAuthGateServiceProvider = Provider<BiopayAuthGateService>((ref) {
  return BiopayAuthGateService();
});

final biopayNfcHceServiceProvider = Provider<BiopayNfcHceService>((ref) {
  return BiopayNfcHceService.instance;
});

final biopayNfcServiceProvider = Provider<BiopayNfcService>((ref) {
  return BiopayNfcService();
});

/// Cache service.
final biopayCacheServiceProvider = Provider<BiopayCacheService>((ref) {
  return BiopayCacheService(
    openBox: <T>(String name) async => Hive.openBox<T>(name),
  );
});

/// Embedding service (singleton lifecycle).
final biopayEmbeddingServiceProvider = Provider<BiopayEmbeddingService>((ref) {
  final service = BiopayEmbeddingService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Config ───────────────────────────────────────────────────

/// BioPay match threshold from app_config.
final biopayMatchThresholdProvider = FutureProvider<double>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.biopayMatchThreshold);
  return double.tryParse(value ?? '') ?? 0.78;
});

/// BioPay cache TTL from app_config.
final biopayCacheTtlHoursProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.biopayCacheTtlHours);
  return int.tryParse(value ?? '') ?? 24;
});

/// BioPay feature enabled flag.
final biopayEnabledProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.biopayEnabled);
  if (value == null) return true;
  return value.toLowerCase() == 'true' || value == '1';
});

// ─── User Profile ─────────────────────────────────────────────

/// Current user's BioPay profile (if enrolled).
final biopayProfileProvider = FutureProvider<BiopayProfile?>((ref) async {
  final repo = ref.watch(biopayRepositoryProvider);
  return repo.fetchCurrentUserProfile();
});

/// Model asset validation issue (null = healthy).
final biopayModelAssetIssueProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(biopayEmbeddingServiceProvider);
  if (!service.isLoaded) {
    await service.loadModel();
  }
  return service.modelIssue;
});

/// Stable frames required before capture.
final biopayStableFramesProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.biopayStableFrames);
  return int.tryParse(value ?? '') ?? 3;
});

/// Face detection service (singleton lifecycle).
final biopayFaceDetectionServiceProvider = Provider<BiopayFaceDetectionService>(
  (ref) {
    final stableFrames = ref.watch(biopayStableFramesProvider).valueOrNull ?? 3;
    final service = BiopayFaceDetectionService(
      stableFramesRequired: stableFrames,
    );
    ref.onDispose(() => service.close());
    return service;
  },
);

/// Face alignment service.
final biopayFaceAlignmentServiceProvider = Provider<BiopayFaceAlignmentService>(
  (ref) {
    return BiopayFaceAlignmentService();
  },
);
