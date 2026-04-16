import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

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
  final String? initialLocation;
  final DeepLinkParser? deepLinkParser;
  final DeepLinkService? deepLinkService;

  const AfriClubApp({
    super.key,
    required this.config,
    required this.modules,
    this.platformConfigSnapshot,
    this.authRepository,
    this.providerOverrides = const <Override>[],
    this.initialLocation,
    this.deepLinkParser,
    this.deepLinkService,
  });

  @override
  State<AfriClubApp> createState() => _AfriClubAppState();
}

class _AfriClubAppState extends State<AfriClubApp> {
  late final AuthRepository _authRepository;
  late final List<Locale> _supportedLocales;

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
  Widget build(BuildContext context) {
    final providerOverrides = <Override>[
      authRepositoryProvider.overrideWithValue(_authRepository),
      ...widget.providerOverrides,
    ];

    return ProviderScope(
      overrides: providerOverrides,
      child: _AfriClubMaterialApp(
        config: widget.config,
        modules: widget.modules,
        supportedLocales: _supportedLocales,
        platformConfigSnapshot: widget.platformConfigSnapshot,
        initialLocation: widget.initialLocation,
        deepLinkParser: widget.deepLinkParser,
        deepLinkService: widget.deepLinkService,
        frameworkLocaleForLanguageCode: _frameworkLocaleForLanguageCode,
      ),
    );
  }

  List<Locale> _buildSupportedLocales(List<String> languages) {
    final seen = <String>{};
    final locales = <Locale>[];

    for (final language in languages) {
      final code = language.trim().toLowerCase();
      if (code.isEmpty || !seen.add(code)) continue;
      locales.add(_frameworkLocaleForLanguageCode(code));
    }

    if (locales.isEmpty) {
      locales.add(_frameworkLocaleForLanguageCode(widget.config.language));
    }

    return locales;
  }

  Locale _frameworkLocaleForLanguageCode(String? languageCode) {
    final code = (languageCode ?? widget.config.language).trim().toLowerCase();
    return switch (code) {
      // Flutter does not ship Material/Cupertino localizations for Kinyarwanda.
      // Use English framework strings until app-specific rw localizations exist.
      'rw' => const Locale('en'),
      'fr' => const Locale('fr'),
      'en' => const Locale('en'),
      _ => Locale(code),
    };
  }
}

class _AfriClubMaterialApp extends ConsumerStatefulWidget {
  const _AfriClubMaterialApp({
    required this.config,
    required this.modules,
    required this.supportedLocales,
    required this.frameworkLocaleForLanguageCode,
    this.platformConfigSnapshot,
    this.initialLocation,
    this.deepLinkParser,
    this.deepLinkService,
  });

  final ClubConfig config;
  final List<FeatureModule> modules;
  final List<Locale> supportedLocales;
  final Map<String, dynamic>? platformConfigSnapshot;
  final String? initialLocation;
  final DeepLinkParser? deepLinkParser;
  final DeepLinkService? deepLinkService;
  final Locale Function(String? languageCode) frameworkLocaleForLanguageCode;

  @override
  ConsumerState<_AfriClubMaterialApp> createState() =>
      _AfriClubMaterialAppState();
}

class _AfriClubMaterialAppState extends ConsumerState<_AfriClubMaterialApp> {
  static const Set<String> _publicPaths = <String>{
    '/splash',
    '/onboarding',
    '/auth/phone',
  };

  late final ValueNotifier<int> _routerRefreshTick;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final AppRouter _appRouter;
  StreamSubscription<Uri>? _deepLinkSubscription;
  bool _initialDeepLinkProcessed = false;

  @override
  void initState() {
    super.initState();

    // ── Hydrate Riverpod feature config from bootstrap snapshot ──
    // The bootstrap sequence already fetched the platform config from Supabase.
    // Inject it into the reactive provider graph so the first frame uses
    // admin-controlled feature states.
    if (widget.platformConfigSnapshot != null) {
      final snapshot = PlatformConfigSnapshot.fromJson(
        widget.platformConfigSnapshot!,
      );
      ref.read(featureConfigProvider.notifier).hydrateFromBootstrap(snapshot);
    }

    _routerRefreshTick = ValueNotifier<int>(0);
    _authSubscription = ref.listenManual<AuthState>(authStateProvider, (_, __) {
      _routerRefreshTick.value = _routerRefreshTick.value + 1;
    });
    _appRouter = AppRouter(
      modules: widget.modules,
      initialLocation: widget.initialLocation,
      refreshListenable: _routerRefreshTick,
      redirect: _handleRedirect,
      observers: [FirebaseAnalyticsService.routeObserver],
      isFeatureEnabled: (path) {
        final segments = path.split('/');
        if (segments.length < 2) return true;
        final firstSegment = segments[1];

        // Map route paths to Supabase feature_keys
        const pathMap = {
          'tickets': 'ticketing',
          'my-tickets': 'ticketing',
          'e-ticket': 'ticketing',
          'contribute': 'contributions',
          'Groups': 'contributions',
          'challenge': 'challenge',
          'fanzone': 'fanzone',
          'fan-clubs': 'fan_clubs',
        };

        final key = pathMap[firstSegment] ?? firstSegment;
        return ref.read(featureConfigServiceProvider).isFeatureEnabled(key);
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
            'Ignoring malformed inbound deep link: $error',
          );
          unawaited(CrashlyticsService.recordError(error, stackTrace));
        },
      );
      unawaited(_applyInitialDeepLink());
    }
  }

  @override
  void dispose() {
    unawaited(_deepLinkSubscription?.cancel());
    _authSubscription.close();
    _routerRefreshTick.dispose();
    super.dispose();
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
    if (internalUri == null) {
      return;
    }

    final match = _appRouter.router.configuration.findMatch(internalUri);
    if (match.isError) {
      return;
    }

    final target = internalUri.toString();
    final current = _appRouter.router.routeInformationProvider.value.uri
        .toString();
    if (target == current) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Use push (not go) to preserve the user's existing navigation history.
      // Deep links should add to the stack, not replace it entirely.
      _appRouter.router.push(target);
    });
  }

  String? _handleRedirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    final authState = ref.read(authStateProvider);

    if (authState is AuthInitial || authState is AuthLoading) {
      if (_isPublicPath(location)) {
        return null;
      }
      return _buildRedirectUri('/splash', state);
    }

    if (authState is AuthAuthenticated) {
      if (_isPublicPath(location)) {
        return _safeDeferredDestination(state) ?? '/home';
      }

      if (location.startsWith('/admin') && !ref.read(hasAdminAccessProvider)) {
        return '/settings';
      }

      return null;
    }

    // Session recovery failed — route to onboarding without preserving
    // the stale deferred destination to avoid redirect loops.
    if (authState is AuthRecoveryRequired || authState is AuthError) {
      if (_isPublicPath(location)) {
        return null;
      }
      return '/onboarding';
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
    final raw = state.uri.queryParameters['from']?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null || !path.startsWith('/') || _isPublicPath(path)) {
      return null;
    }

    final match = _appRouter.router.configuration.findMatch(uri!);
    if (match.isError) {
      return null;
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        ref.watch(currentUserProvider)?.languageCode ?? widget.config.language;
    final appTheme = ClubTheme.from(widget.config);

    // The app is intentionally single-theme: always render with the original
    // dark design system regardless of device appearance settings.
    return MaterialApp.router(
      title: widget.config.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: appTheme,
      darkTheme: appTheme,
      routerConfig: _appRouter.router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
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
        return MediaQuery(
          data: mediaQuery.copyWith(
            // Prevent catastrophic layout breaks while allowing accessible scaling
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.4,
            ),
          ),
          child: ClubConfigScope(
            config: widget.config,
            child: OfflineBanner(child: protectedChild),
          ),
        );
      },
      locale: widget.frameworkLocaleForLanguageCode(languageCode),
      supportedLocales: widget.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
