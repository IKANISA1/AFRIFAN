import 'package:core_auth/core_auth.dart';
import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late final AppRouter _appRouter;
  late final AuthRepository _authRepository;
  late final ThemeData _theme;
  late final List<Locale> _supportedLocales;

  @override
  void initState() {
    super.initState();

    _authRepository =
        widget.authRepository ?? AuthRepository(clubId: widget.config.clubId);
    _theme = ClubTheme.from(widget.config);
    _supportedLocales = _buildSupportedLocales(
      widget.config.supportedLanguages,
    );

    _appRouter = AppRouter(
      modules: widget.modules,
      initialLocation: widget.initialLocation,
      shellBuilder: (context, shell) => AppShell(
        shell: shell,
        config: widget.config,
        modules: widget.modules,
      ),
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
      child: Consumer(
        builder: (context, ref, _) {
          final languageCode =
              ref.watch(currentUserProvider)?.languageCode ??
              widget.config.language;

          return MaterialApp.router(
            title: widget.config.appName,
            debugShowCheckedModeBanner: false,
            theme: _theme,
            routerConfig: _appRouter.router,
            locale: _frameworkLocaleForLanguageCode(languageCode),
            supportedLocales: _supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
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
