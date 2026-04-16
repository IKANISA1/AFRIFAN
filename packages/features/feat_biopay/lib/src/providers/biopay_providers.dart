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
final BioPayRepositoryProvider = Provider<BioPayRepository>((ref) {
  return BioPayRepository(client: ref.watch(supabaseClientProvider));
});

// ─── Services ─────────────────────────────────────────────────

/// Payment handoff service.
final BioPayPaymentHandoffServiceProvider =
    Provider<BioPayPaymentHandoffService>((ref) {
      return const BioPayPaymentHandoffService();
    });

/// Auth gate service.
final BioPayAuthGateServiceProvider = Provider<BioPayAuthGateService>((ref) {
  return BioPayAuthGateService();
});

final BioPayNfcHceServiceProvider = Provider<BioPayNfcHceService>((ref) {
  return BioPayNfcHceService.instance;
});

final BioPayNfcServiceProvider = Provider<BioPayNfcService>((ref) {
  return BioPayNfcService();
});

/// Cache service.
final BioPayCacheServiceProvider = Provider<BioPayCacheService>((ref) {
  return BioPayCacheService(
    openBox: <T>(String name) async => Hive.openBox<T>(name),
    deleteBox: Hive.deleteBoxFromDisk,
  );
});

/// Embedding service (singleton lifecycle).
final BioPayEmbeddingServiceProvider = Provider<BioPayEmbeddingService>((ref) {
  final service = BioPayEmbeddingService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Config ───────────────────────────────────────────────────

/// BioPay match threshold from app_config.
final BioPayMatchThresholdProvider = FutureProvider<double>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.BioPayMatchThreshold);
  return double.tryParse(value ?? '') ?? 0.78;
});

/// BioPay cache TTL from app_config.
final BioPayCacheTtlHoursProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.BioPayCacheTtlHours);
  return int.tryParse(value ?? '') ?? 24;
});

/// BioPay feature enabled flag.
final BioPayEnabledProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.BioPayEnabled);
  if (value == null) return true;
  return value.toLowerCase() == 'true' || value == '1';
});

// ─── User Profile ─────────────────────────────────────────────

/// Current user's BioPay profile (if enrolled).
final BioPayProfileProvider = FutureProvider<BioPayProfile?>((ref) async {
  final repo = ref.watch(BioPayRepositoryProvider);
  return repo.fetchCurrentUserProfile();
});

/// Model asset validation issue (null = healthy).
final BioPayModelAssetIssueProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(BioPayEmbeddingServiceProvider);
  if (!service.isLoaded) {
    await service.loadModel();
  }
  return service.modelIssue;
});

/// Stable frames required before capture.
final BioPayStableFramesProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final configRepo = AppConfigRepository(client: client);
  final value = await configRepo.getValue(AppConfigKeys.BioPayStableFrames);
  return int.tryParse(value ?? '') ?? 3;
});

/// Face detection service (singleton lifecycle).
final BioPayFaceDetectionServiceProvider = Provider<BioPayFaceDetectionService>(
  (ref) {
    final stableFrames = ref.watch(BioPayStableFramesProvider).valueOrNull ?? 3;
    final service = BioPayFaceDetectionService(
      stableFramesRequired: stableFrames,
    );
    ref.onDispose(() => service.close());
    return service;
  },
);

/// Face alignment service.
final BioPayFaceAlignmentServiceProvider = Provider<BioPayFaceAlignmentService>(
  (ref) {
    return BioPayFaceAlignmentService();
  },
);
