import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/src/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('no enabled modules retains a valid built-in recovery route', () {
    final factory = AppRouter(
      modules: const [],
      shellBuilder: (_, __) => const SizedBox.shrink(),
    );
    expect(factory.initialLocation, '/feature-unavailable');
    expect(factory.tabs, isEmpty);
    final router = factory.router;
    addTearDown(router.dispose);
    expect(router, isNotNull);
  });
}
