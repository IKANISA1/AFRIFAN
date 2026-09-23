import 'package:core_feature_config/core_feature_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final repository = FeatureConfigRepository();
  const mobile = PlatformConfigSnapshot(channel: 'mobile');

  test(
    'unscoped historical cache cannot supply any club configuration',
    () async {
      SharedPreferences.setMockInitialValues({
        'africlub_platform_config': mobile.toJsonString(),
      });
      expect(await repository.loadCachedConfig(clubId: 24), isNull);
      expect(await repository.loadCachedConfig(clubId: 25), isNull);
    },
  );

  test('cached configuration is isolated by club and channel', () async {
    SharedPreferences.setMockInitialValues({
      'africlub_platform_config:24:mobile': mobile.toJsonString(),
    });
    expect((await repository.loadCachedConfig(clubId: 24))?.channel, 'mobile');
    expect(await repository.loadCachedConfig(clubId: 25), isNull);
    expect(
      await repository.loadCachedConfig(clubId: 24, channel: 'web'),
      isNull,
    );
  });

  test('corrupt scoped cache does not fall back to unscoped state', () async {
    SharedPreferences.setMockInitialValues({
      'africlub_platform_config:24:mobile': '{invalid',
      'africlub_platform_config': mobile.toJsonString(),
    });
    expect(await repository.loadCachedConfig(clubId: 24), isNull);
  });
}
