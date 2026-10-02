import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'deep_link_service.dart';
import 'shell.dart';

/// The root AFRICLUB MaterialApp.
///
/// Consumes ClubConfig → generates ClubTheme → wires GoRouter.
class AfriClubApp extends StatefulWidget {
  final ClubConfig config;
  final List<FeatureModule> modules;
  final Map<String, dynamic>? platformConfigSnapshot;
  final AuthRepository? authRepository;
  final List<Override> providerOverrides;
  final List<ProviderListenable<Object?>> eagerProviders;
  final VoidCallback? onAccountChanged;
  final String? initialLocation;
  final DeepLinkParser? deepLinkParser;
  final DeepLinkService? deepLinkService;
  final Stream<Uri>? notificationRouteStream;

  const AfriClubApp({
    super.key,
    required this.config,
    required this.modules,
    this.platformConfigSnapshot,
    this.authRepository,
    this.providerOverrides = const <Override>[],
    this.eagerProviders = const <ProviderListenable<Object?>>[],
    this.onAccountChanged,
    this.initialLocation,
    this.deepLinkParser,
    this.deepLinkService,
    this.notificationRouteStream,
  });

  @override
  State<AfriClubApp> createState() => _AfriClubAppState();
}

class _AfriClubAppState extends State<AfriClubApp> {
  late AuthRepository _authRepository;
  late List<Locale> _supportedLocales;
  var _clubScopeGeneration = 0;

  @override
  void initState() {
    super.initState();

    _authRepository =
        widget.authRepository ?? AuthRepository(clubId: widget.config.clubId);
    _supportedLocales = _buildSupportedLocales(
      widget.config.supportedLanguages,
    );
  }

  @override
  void didUpdateWidget(covariant AfriClubApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clubChanged = oldWidget.config.clubId != widget.config.clubId;
    final repositoryChanged = !identical(
      oldWidget.authRepository,
      widget.authRepository,
    );
    if (clubChanged || repositoryChanged) {
      _authRepository.invalidatePendingAuthentication();
      // Close the previous account's in-memory views before replacing its
      // repository. Protected operation journals keep their existing authority.
      oldWidget.onAccountChanged?.call();
      _authRepository =
          widget.authRepository ?? AuthRepository(clubId: widget.config.clubId);
    }
    if (clubChanged) {
      // A router and its providers are scoped to one club. Recreate both rather
      // than retaining old route, feature and account state under new branding.
      _clubScopeGeneration++;
    }
    _supportedLocales = _buildSupportedLocales(
      widget.config.supportedLanguages,
    );
  }

  @override
  void dispose() {
    _authRepository.invalidatePendingAuthentication();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapSnapshot = widget.platformConfigSnapshot == null
        ? null
        : PlatformConfigSnapshot.fromJson(widget.platformConfigSnapshot!);
    final providerOverrides = <Override>[
      authRepositoryProvider.overrideWithValue(_authRepository),
      if (bootstrapSnapshot != null)
        initialFeatureConfigSnapshotProvider.overrideWithValue(
          bootstrapSnapshot,
        ),
      ...widget.providerOverrides,
    ];

    return ProviderScope(
      key: ValueKey(_clubScopeGeneration),
      overrides: providerOverrides,
      child: _AfriClubMaterialApp(
        authRepository: _authRepository,
        config: widget.config,
        modules: widget.modules,
        eagerProviders: widget.eagerProviders,
        onAccountChanged: widget.onAccountChanged,
        supportedLocales: _supportedLocales,
        platformConfigSnapshot: widget.platformConfigSnapshot,
        initialLocation: widget.initialLocation,
        deepLinkParser: widget.deepLinkParser,
        deepLinkService: widget.deepLinkService,
        notificationRouteStream: widget.notificationRouteStream,
        frameworkLocaleForLanguageCode: _frameworkLocaleForLanguageCode,
        appLocaleForLanguageCode: _appLocaleForLanguageCode,
      ),
    );
  }

  List<Locale> _buildSupportedLocales(List<String> languages) => const <Locale>[
    Locale('en'),
  ];

  Locale _frameworkLocaleForLanguageCode(String? languageCode) =>
      const Locale('en');

  Locale _appLocaleForLanguageCode(String? languageCode) => const Locale('en');
}

class _AfriClubMaterialApp extends ConsumerStatefulWidget {
  const _AfriClubMaterialApp({
    required this.authRepository,
    required this.config,
    required this.modules,
    required this.supportedLocales,
    this.eagerProviders = const <ProviderListenable<Object?>>[],
    this.onAccountChanged,
    required this.frameworkLocaleForLanguageCode,
    required this.appLocaleForLanguageCode,
    this.platformConfigSnapshot,
    this.initialLocation,
    this.deepLinkParser,
    this.deepLinkService,
    this.notificationRouteStream,
  });

  final ClubConfig config;
  final AuthRepository authRepository;
  final List<FeatureModule> modules;
  final List<Locale> supportedLocales;
  final List<ProviderListenable<Object?>> eagerProviders;
  final VoidCallback? onAccountChanged;
  final Map<String, dynamic>? platformConfigSnapshot;
  final String? initialLocation;
  final DeepLinkParser? deepLinkParser;
  final DeepLinkService? deepLinkService;
  final Stream<Uri>? notificationRouteStream;
  final Locale Function(String? languageCode) frameworkLocaleForLanguageCode;
  final Locale Function(String? languageCode) appLocaleForLanguageCode;

  @override
  ConsumerState<_AfriClubMaterialApp> createState() =>
      _AfriClubMaterialAppState();
}

class _AfriClubMaterialAppState extends ConsumerState<_AfriClubMaterialApp>
    with WidgetsBindingObserver {
  /// Aggregated public paths from all registered modules plus system routes.
  /// These paths bypass the authentication redirect guard.
  late final Set<String> _publicPaths = <String>{
    '/feature-unavailable',
    for (final module in widget.modules) ...module.publicPaths,
  };

  late final ValueNotifier<int> _routerRefreshTick;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<AsyncValue<PlatformConfigSnapshot>>
  _featureConfigSubscription;
  late final AppRouter _appRouter;
  StreamSubscription<Uri>? _deepLinkSubscription;
  StreamSubscription<Uri>? _notificationRouteSubscription;
  bool _initialDeepLinkProcessed = false;
  late final int? _normalizedClubId;

  @override
  void initState() {
    super.initState();

    _normalizedClubId = int.tryParse(widget.config.clubId);
    _routerRefreshTick = ValueNotifier<int>(0);
    _authSubscription = ref.listenManual<AuthState>(authStateProvider, (
      old,
      next,
    ) {
      if (old is AuthAuthenticated &&
          (next is! AuthAuthenticated ||
              old.user.id != next.user.id ||
              old.user.clubId != next.user.clubId)) {
        // Private native views close on a global account transition. Their
        // separate protected authority/journals are not revoked or retried.
        widget.onAccountChanged?.call();
      }
      _routerRefreshTick.value = _routerRefreshTick.value + 1;
    });
    _featureConfigSubscription = ref
        .listenManual<AsyncValue<PlatformConfigSnapshot>>(
          featureConfigProvider,
          (_, __) {
            _routerRefreshTick.value = _routerRefreshTick.value + 1;
          },
        );
    _appRouter = AppRouter(
      modules: widget.modules,
      initialLocation: widget.initialLocation,
      refreshListenable: _routerRefreshTick,
      redirect: _handleRedirect,
      observers: [FirebaseAnalyticsService.routeObserver],
      isFeatureEnabled: (path) {
        // Keep the primary Predict destination in its shell when the service
        // is unavailable. PredictController still gates every read and write
        // on authentication and the current capability/store policy.
        if (path == '/predict') return true;
        return ref.read(featureConfigServiceProvider).isRouteAvailable(path);
      },
      shellBuilder: (context, shell) => AppShell(
        shell: shell,
        config: widget.config,
        modules: widget.modules,
      ),
    );
    if (widget.deepLinkParser != null && widget.deepLinkService != null) {
      _deepLinkSubscription = widget.deepLinkService!.uriStream.listen(
        _handleIncomingDeepLink,
        onError: (Object error, StackTrace stackTrace) {
          AfriLogger.warn(
            'AfriClubApp',
            'Ignoring malformed inbound deep link.',
            error,
          );
          unawaited(CrashlyticsService.recordError(error, stackTrace));
        },
      );
      unawaited(_applyInitialDeepLink());
    }
    _notificationRouteSubscription = widget.notificationRouteStream?.listen(
      _handleNotificationRoute,
      onError: (Object error, StackTrace stackTrace) {
        AfriLogger.warn(
          'AfriClubApp',
          'Ignoring malformed notification route.',
          error,
        );
        unawaited(CrashlyticsService.recordError(error, stackTrace));
      },
    );

    WidgetsBinding.instance.addObserver(this);
    _scheduleAuthRestore();
    _scheduleFeatureConfigRefresh();
  }

  @override
  void didUpdateWidget(covariant _AfriClubMaterialApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.authRepository, widget.authRepository)) {
      // Riverpod rebuilds auth against the replacement repository. Restore the
      // new session after that update without disposing the same-club protected
      // journey owner supplied by the caller.
      _scheduleAuthRestore();
      _routerRefreshTick.value = _routerRefreshTick.value + 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_deepLinkSubscription?.cancel());
    unawaited(_notificationRouteSubscription?.cancel());
    _authSubscription.close();
    _featureConfigSubscription.close();
    _appRouter.router.dispose();
    _routerRefreshTick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cached staff grants expire on resume; refresh the current assignment.
      unawaited(ref.read(authStateProvider.notifier).refreshAdminAccess());
      // Purge expired cache entries after returning from background.
      // Users may have been away for hours — stale data is worse than a
      // fresh network fetch.
      unawaited(HiveCacheService.purgeExpired());

      // Re-sync push token — the OS may have rotated it while backgrounded.
      unawaited(PushNotificationService.syncToken());
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted && ref.read(themeModeProvider) == ThemeMode.system) {
      setState(() {});
    }
  }

  void _scheduleFeatureConfigRefresh() {
    final clubId = _normalizedClubId;
    if (clubId == null || !SupabaseClientFactory.isInitialized) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(featureConfigProvider.notifier).loadForClub(clubId));
    });
  }

  void _scheduleAuthRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final authState = ref.read(authStateProvider);
      if (authState is! AuthInitial) {
        return;
      }

      unawaited(
        ref
            .read(authStateProvider.notifier)
            .restore()
            .timeout(const Duration(seconds: 15))
            .catchError((Object error, StackTrace stackTrace) {
              AfriLogger.warn(
                'AfriClubApp',
                'Session restore failed during app startup.',
                error,
                stackTrace,
              );
            }),
      );
    });
  }

  Future<void> _applyInitialDeepLink() async {
    if (_initialDeepLinkProcessed || widget.initialLocation != null) {
      return;
    }
    _initialDeepLinkProcessed = true;
    final uri = await widget.deepLinkService?.getInitialUri();
    if (!mounted || uri == null) {
      return;
    }
    _handleIncomingDeepLink(uri);
  }

  void _handleIncomingDeepLink(Uri incomingUri) {
    final parser = widget.deepLinkParser;
    if (parser == null) {
      return;
    }

    final internalUri = parser.toInternalUri(incomingUri);
    _navigateToInternalRoute(internalUri);
  }

  void _handleNotificationRoute(Uri internalUri) {
    _navigateToInternalRoute(internalUri);
  }

  void _navigateToInternalRoute(Uri? internalUri) {
    final safeInternalUri = InternalRouteUriPolicy.validate(internalUri);
    if (safeInternalUri == null) {
      return;
    }

    final match = _appRouter.router.configuration.findMatch(safeInternalUri);
    if (match.isError) {
      return;
    }

    final target = safeInternalUri.toString();
    final current = _appRouter.router.routeInformationProvider.value.uri
        .toString();
    if (target == current) {
      return;
    }

    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_isShellDestination(safeInternalUri.path)) {
        // Stateful-shell destinations must switch branches. Pushing a tab
        // route can render its content over the current branch while leaving
        // the wrong navigation destination selected.
        _appRouter.router.go(target);
      } else {
        // Standalone task links add to the current history.
        unawaited(_appRouter.router.push(target));
      }
    });
    // A warm link can arrive while Flutter is completely idle. Registering a
    // post-frame callback does not itself guarantee that another frame will be
    // produced, so explicitly wake the scheduler.
    binding.ensureVisualUpdate();
  }

  bool _isShellDestination(String path) {
    for (final module in widget.modules) {
      final tab = module.tabRoute;
      if (tab == null || !shellBranchFeatureKeys.contains(module.featureKey)) {
        continue;
      }
      if (path == tab.path || path.startsWith('${tab.path}/')) {
        return true;
      }
    }
    return false;
  }

  String? _handleRedirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    if (widget.modules.any(
      (module) => module.independentlyAuthenticatedPaths.contains(location),
    )) {
      return null;
    }
    final authState = ref.read(authStateProvider);

    if (PublicReadRoutes.allows(state.uri)) return null;

    if (authState is AuthInitial || authState is AuthLoading) {
      if (_isPublicPath(location)) {
        return null;
      }
      return null;
    }

    if (authState is AuthAuthenticated) {
      final profileClubId = int.tryParse(authState.user.clubId);
      if (_normalizedClubId == null || profileClubId != _normalizedClubId) {
        // A session for another club cannot authorize private destinations in
        // this router. Independently scoped native entry routes use their own
        // authority above; public reads remain available without this grant.
        return _isPublicPath(location)
            ? null
            : _buildRedirectUri('/auth/phone', state);
      }
      if (location == '/feature-unavailable') {
        return null;
      }

      if (_isPublicPath(location)) {
        return _safeDeferredDestination(state) ?? '/home';
      }

      if (location.startsWith('/admin') && !ref.read(hasAdminAccessProvider)) {
        return '/settings';
      }

      return null;
    }

    // B-6: Session recovery failed — redirect to re-authentication with
    // the user's current location preserved so they can return after re-auth.
    if (authState is AuthRecoveryRequired || authState is AuthError) {
      if (_isPublicPath(location)) {
        return null;
      }
      // Route to phone auth instead of generic onboarding so the user
      // sees a clear "session expired" re-auth flow with their destination
      // preserved via the `from` query parameter.
      return _buildRedirectUri('/auth/phone', state);
    }

    if (_isPublicPath(location)) {
      return null;
    }

    return _buildRedirectUri('/onboarding', state);
  }

  bool _isPublicPath(String location) => _publicPaths.contains(location);

  String _buildRedirectUri(String publicPath, GoRouterState state) {
    final requestedLocation = state.uri.toString();
    return Uri(
      path: publicPath,
      queryParameters: <String, String>{'from': requestedLocation},
    ).toString();
  }

  String? _safeDeferredDestination(GoRouterState state) {
    final String? raw;
    try {
      raw = state.uri.queryParameters['from']?.trim();
    } on FormatException {
      return null;
    }
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final safeUri = InternalRouteUriPolicy.parse(raw);
    final path = safeUri?.path;
    if (safeUri == null ||
        path == null ||
        !path.startsWith('/') ||
        _isPublicPath(path)) {
      return null;
    }

    final match = _appRouter.router.configuration.findMatch(safeUri);
    if (match.isError) {
      return null;
    }

    return safeUri.toString();
  }

  @override
  Widget build(BuildContext context) {
    for (final provider in widget.eagerProviders) {
      ref.watch(provider);
    }
    final languageCode =
        ref.watch(currentUserProvider)?.languageCode ?? widget.config.language;
    final appLocale = widget.appLocaleForLanguageCode(languageCode);
    final themeMode = ref.watch(themeModeProvider);
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final activeBrightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => systemBrightness,
    };
    ColorTokens.setBrightness(activeBrightness);
    final lightTheme = ClubTheme.from(
      widget.config,
      brightness: Brightness.light,
    );
    final darkTheme = ClubTheme.from(
      widget.config,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: widget.config.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: _appRouter.router,
      builder: (context, child) {
        final appChild = child ?? const SizedBox.shrink();
        final protectedChild = kReleaseMode || kProfileMode
            ? AfriErrorBoundary(
                onError: (error, stack) {
                  AfriLogger.error(
                    'AfriClubApp',
                    'Caught widget tree error.',
                    error,
                    stack,
                  );
                  unawaited(CrashlyticsService.recordError(error, stack));
                },
                child: appChild,
              )
            : appChild;
        final scopedChild = ClubConfigScope(
          config: widget.config,
          child: OfflineBanner(child: protectedChild),
        );
        final localizedChild = AfriLocalizationsScope(
          locale: appLocale,
          child: scopedChild,
        );
        final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
        if (!highContrast) {
          return localizedChild;
        }
        return Theme(
          data: ClubTheme.from(
            widget.config,
            brightness: Theme.of(context).brightness,
            highContrast: true,
          ),
          child: localizedChild,
        );
      },
      locale: widget.frameworkLocaleForLanguageCode(languageCode),
      supportedLocales: widget.supportedLocales,
      localizationsDelegates: const [
        AfriLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
