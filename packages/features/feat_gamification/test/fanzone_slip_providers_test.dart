import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/fanzone_slip_providers.dart';
import 'package:feat_gamification/src/models/fanzone_slip_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:feat_gamification/src/repositories/prediction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _FakePredictionRepository extends PredictionRepository {
  _FakePredictionRepository({this.shouldSucceed = true})
    : super(client: _MockSupabaseClient());

  final bool shouldSucceed;

  @override
  Future<PredictionPlaceResult> placePrediction({
    required String fixtureMarketId,
    required String selectedOutcome,
  }) async {
    if (shouldSucceed) {
      return const PredictionPlaceResult(
        status: 'placed',
        message: 'Prediction placed.',
      );
    }
    return const PredictionPlaceResult(
      status: 'error',
      message: 'Prediction failed.',
    );
  }

  @override
  Future<PredictionPlaceResult> placeAcca(
    List<Map<String, String>> selections,
  ) async {
    if (shouldSucceed) {
      return const PredictionPlaceResult(
        status: 'placed',
        message: 'Acca placed.',
        slipId: 'slip-1',
      );
    }
    return const PredictionPlaceResult(
      status: 'error',
      message: 'Acca failed.',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fanzone_slip_test_');
    Hive.init(tempDir.path);
    await HiveCacheService.resetForTest(deleteBox: true);
    await HiveCacheService.initialize();
  });

  tearDown(() async {
    await HiveCacheService.resetForTest(deleteBox: true);
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FanzoneSlipController persistence', () {
    test('restores cached slip selections and acca mode', () async {
      final firstContainer = ProviderContainer(
        overrides: <Override>[
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(),
          ),
        ],
      );

      final notifier = firstContainer.read(fanzoneSlipProvider.notifier);
      notifier.addSelection(_selection());
      notifier.toggleAcca(true);
      await _settlePersistence();
      firstContainer.dispose();

      final restoredContainer = ProviderContainer(
        overrides: <Override>[
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(),
          ),
        ],
      );
      addTearDown(restoredContainer.dispose);

      final restored = restoredContainer.read(fanzoneSlipProvider);
      expect(restored.accaMode, isTrue);
      expect(restored.items, hasLength(1));
      expect(restored.items.single.fixtureMarketId, 'market-1');
      expect(restored.items.single.outcomeKey, 'home');
    });

    test('clears persisted slip after successful submission', () async {
      final firstContainer = ProviderContainer(
        overrides: <Override>[
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(),
          ),
        ],
      );

      final notifier = firstContainer.read(fanzoneSlipProvider.notifier);
      notifier.addSelection(_selection());
      await _settlePersistence();

      final result = await notifier.submit();
      expect(result.submittedCount, 1);
      await _settlePersistence();
      firstContainer.dispose();

      final restoredContainer = ProviderContainer(
        overrides: <Override>[
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(),
          ),
        ],
      );
      addTearDown(restoredContainer.dispose);

      final restored = restoredContainer.read(fanzoneSlipProvider);
      expect(restored.items, isEmpty);
      expect(restored.accaMode, isFalse);
    });

    test('keeps persisted slip when submission fails', () async {
      final firstContainer = ProviderContainer(
        overrides: <Override>[
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(shouldSucceed: false),
          ),
        ],
      );

      final notifier = firstContainer.read(fanzoneSlipProvider.notifier);
      notifier.addSelection(_selection());
      notifier.toggleAcca(true);
      await _settlePersistence();

      final result = await notifier.submit();
      expect(result.failedCount, 1);
      await _settlePersistence();
      firstContainer.dispose();

      final restoredContainer = ProviderContainer(
        overrides: <Override>[
          predictionRepositoryProvider.overrideWithValue(
            _FakePredictionRepository(shouldSucceed: false),
          ),
        ],
      );
      addTearDown(restoredContainer.dispose);

      final restored = restoredContainer.read(fanzoneSlipProvider);
      expect(restored.accaMode, isTrue);
      expect(restored.items, hasLength(1));
      expect(restored.items.single.fixtureMarketId, 'market-1');
    });
  });
}

FanzoneSlipSelection _selection() {
  return const FanzoneSlipSelection(
    fixtureId: 'fixture-1',
    fixtureLabel: 'Rayon Sports vs APR',
    fixtureMarketId: 'market-1',
    marketName: 'Match Result',
    marketSlug: '1x2',
    outcomeKey: 'home',
    outcomeLabel: 'Rayon Sports',
    fetPotential: 120,
    competitionName: 'Rwanda Premier League',
  );
}

Future<void> _settlePersistence() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
