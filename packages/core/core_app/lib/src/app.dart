import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

import 'shell.dart';

/// The root AFRICLUB MaterialApp.
///
/// Consumes ClubConfig → generates ClubTheme → wires GoRouter.
class AfriClubApp extends StatefulWidget {
  final ClubConfig config;
  final List<FeatureModule> modules;
  final AuthRepository? authRepository;
  final List<Override> providerOverrides;
  final String? initialLocation;

  const AfriClubApp({
    super.key,
    required this.config,
    required this.modules,
    this.authRepository,
    this.providerOverrides = const <Override>[],
    this.initialLocation,
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
        initialLocation: widget.initialLocation,
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
    this.initialLocation,
  });

  final ClubConfig config;
  final List<FeatureModule> modules;
  final List<Locale> supportedLocales;
  final String? initialLocation;
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

  @override
  void initState() {
    super.initState();
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
      shellBuilder: (context, shell) => AppShell(
        shell: shell,
        config: widget.config,
        modules: widget.modules,
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription.close();
    _routerRefreshTick.dispose();
    super.dispose();
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

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode =
        ref.watch(currentUserProvider)?.languageCode ?? widget.config.language;
    final themeMode = ref.watch(themeModeProvider);
    const lockedBrightness = Brightness.dark;
    final appTheme = ClubTheme.from(
      widget.config,
      brightness: lockedBrightness,
    );

    // The app is intentionally single-theme: always render with the original
    // dark design system regardless of device appearance settings.
    ColorTokens.setBrightness(lockedBrightness);

    return MaterialApp.router(
      title: widget.config.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: appTheme,
      darkTheme: appTheme,
      routerConfig: _appRouter.router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            // Prevent catastrophic layout breaks while allowing accessible scaling
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.4,
            ),
            accessibleNavigation: true,
          ),
          child: ClubConfigScope(
            config: widget.config,
            child: child ?? const SizedBox.shrink(),
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
