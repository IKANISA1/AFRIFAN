import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'module_registry.dart';
import 'startup_coordinator.dart';

class AfriClubBootstrapOptions {
  const AfriClubBootstrapOptions({
    this.startupOptions = const AppStartupOptions(),
    this.modulesOverride,
    this.authRepository,
    this.providerOverrides = const <Override>[],
    this.initialLocation,
  });

  final AppStartupOptions startupOptions;
  final List<FeatureModule>? modulesOverride;
  final AuthRepository? authRepository;
  final List<Override> providerOverrides;
  final String? initialLocation;
}

/// Bootstrap the AFRICLUB app with club config.
///
/// The startup coordinator owns side effects, while the module registry owns
/// feature composition. This keeps each club entrypoint declarative.
Future<void> bootstrap(
  ClubConfig config, {
  AfriClubBootstrapOptions options = const AfriClubBootstrapOptions(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppStartupCoordinator(
    options: options.startupOptions,
  ).initialize(config);
  final modules = options.modulesOverride ?? AppModuleRegistry.build(config);

  // Run the app
  runApp(
    AfriClubApp(
      config: config,
      modules: modules,
      authRepository: options.authRepository,
      providerOverrides: options.providerOverrides,
      initialLocation: options.initialLocation,
    ),
  );
}
