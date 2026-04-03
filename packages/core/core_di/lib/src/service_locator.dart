import 'package:get_it/get_it.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initialize the service locator with all dependencies.
///
/// Called during app bootstrap. Feature modules register
/// their own providers via this locator.
Future<void> initServiceLocator() async {
  // Core services are registered by the app bootstrap.
  // Feature-specific services are registered by each FeatureModule.
}
