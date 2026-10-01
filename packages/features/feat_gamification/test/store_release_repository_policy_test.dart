import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:feat_gamification/src/predict/predict_controller.dart';
import 'package:feat_gamification/src/predict/predict_models.dart';
import 'package:feat_gamification/src/predict/predict_repository.dart';
import 'package:feat_gamification/src/repositories/partner_pool_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  const policy = StoreReleasePolicy(isEnforced: true);

  group('store release repository policy', () {
    test('the unavailable Predict tab cannot reach a data client', () async {
      final container = ProviderContainer(
        overrides: [
          featureConfigServiceProvider.overrideWithValue(
            const FeatureConfigService(
              PlatformConfigSnapshot(),
              storeReleasePolicy: StoreReleasePolicy.unenforced(),
            ),
          ),
          supabaseClientProvider.overrideWith(
            (ref) => throw StateError('Network client must not be read'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final gateway = container.read(predictGatewayProvider);
      final status = await gateway.load();
      expect(status.enabled, isFalse);
      expect(status.fixtures, isEmpty);
      expect(status.balanceFet, isNull);
      await expectLater(
        gateway.place('fixture-1', PredictSelection.home),
        throwsA(PredictFailure.unavailable),
      );
    });

    test(
      'Predict reads and mutations fail closed before network access',
      () async {
        final client = _MockSupabaseClient();
        final predict = PredictRepository(client, storeReleasePolicy: policy);
        await expectLater(predict.load(), throwsA(PredictFailure.unavailable));
        await expectLater(
          predict.place('fixture-1', PredictSelection.home),
          throwsA(PredictFailure.unavailable),
        );
        final pools = PartnerPoolRepository(
          client: client,
          storeReleasePolicy: policy,
        );
        expect(await pools.loadPools(), isEmpty);
        await expectLater(
          pools.joinPool(poolId: 'pool-1', selectedOutcome: 'home'),
          throwsA(isA<UnsupportedError>()),
        );
        verifyNever(() => client.auth);
      },
    );
  });
}
