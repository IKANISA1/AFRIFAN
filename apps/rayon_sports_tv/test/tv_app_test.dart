import 'dart:async';
import 'dart:io';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayon_sports_tv/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders native TV-safe code state without private data', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1280, 720));

    await tester.pumpWidget(
      const RayonSportsTvApp(
        state: TvDisplayState(
          venueName: 'Kigali Arena',
          sessionCode: 'SCREEN24',
          expiresAt: '21:45',
          fetReward: 25,
          prompt: 'Join from the supporter app.',
          phase: 'Open',
        ),
      ),
    );

    expect(find.text('Gikundiro TV'), findsOneWidget);
    expect(find.text('Kigali Arena'), findsOneWidget);
    expect(find.text('SCREEN24'), findsOneWidget);
    expect(find.text('25 FET reward'), findsOneWidget);
    expect(find.text('Expires 21:45'), findsOneWidget);

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join('\n')
        .toLowerCase();

    expect(visibleText, isNot(contains('phone')));
    expect(visibleText, isNot(contains('email')));
    expect(visibleText, isNot(contains('order queue')));
    expect(visibleText, isNot(contains('wallet')));
  });

  testWidgets('renders without overflow on 1080p TV surface', (tester) async {
    _setTvSurface(tester, const Size(1920, 1080));

    await tester.pumpWidget(
      const RayonSportsTvApp(state: TvDisplayState.unpaired),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gikundiro TV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rayon TV uses the real Kinyarwanda task-copy catalog', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1280, 720));
    final rw = lookupAfriLocalizations(const Locale('rw'));

    await tester.pumpWidget(
      const RayonSportsTvApp(state: TvDisplayState.unpaired),
    );
    await tester.pumpAndSettle();

    expect(find.text(rw.tvJoinFromFanZone), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const <Size>[
    Size(1280, 720),
    Size(1920, 1080),
    Size(3840, 2160),
  ]) {
    testWidgets('renders session state without overflow at ${size.width}x'
        '${size.height}', (tester) async {
      _setTvSurface(tester, size);

      await tester.pumpWidget(
        const RayonSportsTvApp(
          state: TvDisplayState(
            venueName: 'Stade ya Kigali Pele — Irembo ry’abafana n’abashyitsi',
            sessionCode: 'KGL2026',
            expiresAt: '2020-01-01T00:00:00Z',
            fetReward: 25,
            prompt: 'Injira ukoresheje Fan Zone.',
            phase: 'Open',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KGL2026'), findsOneWidget);
      expect(find.text('Expires expired'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final state in const <TvConnectionState>[
    TvConnectionState.unpaired,
    TvConnectionState.revoked,
    TvConnectionState.configurationMissing,
  ]) {
    testWidgets('renders $state pairing state at 720p', (tester) async {
      _setTvSurface(tester, const Size(1280, 720));

      await tester.pumpWidget(
        MaterialApp(
          home: TvPairingScreen(state: state, onPair: (_) async => null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pair this TV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in const <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ]) {
    testWidgets('${locale.languageCode} pairing recovery copy fits at 720p', (
      tester,
    ) async {
      _setTvSurface(tester, const Size(1280, 720));
      final l10n = lookupAfriLocalizations(locale);

      await tester.pumpWidget(
        _localizedTvSurface(
          locale: locale,
          child: TvPairingScreen(
            state: TvConnectionState.revoked,
            onPair: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.tvCredentialRevoked), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('respects reduced-motion media settings', (tester) async {
    _setTvSurface(tester, const Size(1280, 720));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: RayonSportsTvScreen(state: TvDisplayState.unpaired),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAIR TV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV pairing focus changes have zero decorative duration', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1280, 720));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: TvPairingScreen(
            state: TvConnectionState.unpaired,
            onPair: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pump();

    final animatedContainers = tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: find.byType(AfriButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(animatedContainers, isNotEmpty);
    expect(
      animatedContainers.every((widget) => widget.duration == Duration.zero),
      isTrue,
    );
    expect(find.text('Pair display'), findsOneWidget);
  });

  test('Android manifest declares native TV launch contract', () {
    final manifest = File(
      '${_packageRootPrefix()}android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.software.leanback'));
    expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
    expect(manifest, contains('android.hardware.touchscreen'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    final forbiddenIconRef =
        '@mipmap/'
        'ic_'
        'launcher';
    expect(manifest, isNot(contains(forbiddenIconRef)));
  });

  test('Android release contract rejects debug signing', () {
    final gradle = File(
      '${_packageRootPrefix()}android/app/build.gradle.kts',
    ).readAsStringSync();
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gradle, contains('TV_ANDROID_KEYSTORE_PATH'));
    expect(gradle, contains('TV release signing credentials are required'));
  });

  test('TV provisioning contract contains no compile-time device secret', () {
    final source = File(
      '${_packageRootPrefix()}lib/main.dart',
    ).readAsStringSync();
    expect(source, isNot(contains("String.fromEnvironment('TV_DEVICE_ID')")));
    expect(
      source,
      isNot(contains("String.fromEnvironment('TV_PAIRING_CODE')")),
    );
    expect(source, contains('exchange_tv_pairing_code'));
    expect(source, contains('get_tv_display_state_with_credential'));
    expect(source, contains('FlutterSecureStorage'));
  });

  test('malformed TV payload fails closed without exposing values', () {
    final state = TvDisplayState.fromRpcPayload(<String, Object?>{
      'venue_name': '',
      'session_code': null,
      'fet_reward': 'invalid',
    });
    expect(state.venueName, 'Unpaired TV display');
    expect(state.sessionCode, 'PAIR TV');
    expect(state.fetReward, 0);
    expect(state.phase, 'Offline');
  });

  test('ISO expiry is rendered as a bounded countdown', () {
    final state = TvDisplayState(
      venueName: 'Venue',
      sessionCode: 'CODE1234',
      expiresAt: '2026-07-18T12:30:00Z',
      fetReward: 0,
      prompt: 'Prompt',
      phase: 'Open',
    );
    expect(
      state.expiryLabel(DateTime.parse('2026-07-18T12:00:00Z')),
      'in 30 min',
    );
    expect(
      state.expiryLabel(DateTime.parse('2026-07-18T12:31:00Z')),
      'expired',
    );
  });

  testWidgets('remote Enter and retry shortcut activate recovery', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1280, 720));
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RayonSportsTvScreen(
          state: TvDisplayState.unpaired,
          connectionState: TvConnectionState.serviceUnavailable,
          onRetry: () => retryCount += 1,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Connection lost — retry'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(retryCount, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(retryCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'D-pad reaches pairing submit and failed pairing restores input focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      _setTvSurface(tester, const Size(1280, 720));
      String? submittedCode;
      await tester.pumpWidget(
        MaterialApp(
          home: TvPairingScreen(
            state: TvConnectionState.unpaired,
            onPair: (code) async {
              submittedCode = code;
              return 'That pairing code is invalid or expired.';
            },
          ),
        ),
      );
      await tester.pump();

      final inputFinder = find.byKey(
        const ValueKey<String>('tv-pairing-code-input'),
      );
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'ABC123');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV pair display');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(submittedCode, 'ABC123');
      expect(find.text('That pairing code is invalid or expired.'), findsOne);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV pairing code');
      var textField = tester.widget<TextField>(
        find.descendant(of: inputFinder, matching: find.byType(TextField)),
      );
      expect(textField.controller?.text, 'ABC123');
      expect(textField.autofillHints, isEmpty);
      expect(
        find.bySemanticsLabel(
          'One-time pairing code. Error: '
          'That pairing code is invalid or expired.',
        ),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV pair display');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      textField = tester.widget<TextField>(
        find.descendant(of: inputFinder, matching: find.byType(TextField)),
      );
      expect(textField.controller?.text, isEmpty);
      expect(
        find.text('That pairing code is invalid or expired.'),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets('pairing blocks duplicate submit and retains the busy draft', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1280, 720));
    final gate = Completer<String?>();
    var submitCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TvPairingScreen(
          state: TvConnectionState.unpaired,
          onPair: (code) {
            submitCount += 1;
            return gate.future;
          },
        ),
      ),
    );
    await tester.pump();

    final inputFinder = find.byKey(
      const ValueKey<String>('tv-pairing-code-input'),
    );
    await tester.enterText(inputFinder, 'ABC123');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(submitCount, 1);
    expect(find.text('Pairing…'), findsOneWidget);
    final textField = tester.widget<TextField>(
      find.descendant(of: inputFinder, matching: find.byType(TextField)),
    );
    expect(textField.enabled, isFalse);
    expect(textField.controller?.text, 'ABC123');
    expect(textField.maxLength, 12);
    expect(textField.textCapitalization, TextCapitalization.characters);

    gate.complete('That pairing code is invalid or expired.');
    await tester.pumpAndSettle();
    expect(submitCount, 1);
  });

  testWidgets('Android system Back clears pairing state before leaving', (
    tester,
  ) async {
    _setTvSurface(tester, const Size(1920, 1080));
    await tester.pumpWidget(
      MaterialApp(
        home: TvPairingScreen(
          state: TvConnectionState.unpaired,
          onPair: (_) async => 'Pairing service is unavailable.',
        ),
      ),
    );
    await tester.pump();

    final inputFinder = find.byKey(
      const ValueKey<String>('tv-pairing-code-input'),
    );
    await tester.enterText(inputFinder, 'TVTEST26');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TvPairingScreen), findsOneWidget);
    final textField = tester.widget<TextField>(
      find.descendant(of: inputFinder, matching: find.byType(TextField)),
    );
    expect(textField.controller?.text, isEmpty);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV pairing code');
    expect(tester.takeException(), isNull);
  });

  test('remote shortcut map covers directional, select, back, and submit', () {
    const shortcuts = TvRemoteControlScope.shortcuts;

    expect(
      shortcuts[const SingleActivator(LogicalKeyboardKey.arrowUp)],
      isA<DirectionalFocusIntent>(),
    );
    expect(
      shortcuts[const SingleActivator(LogicalKeyboardKey.select)],
      isA<ActivateIntent>(),
    );
    expect(
      shortcuts[const SingleActivator(LogicalKeyboardKey.browserBack)],
      isA<TvBackIntent>(),
    );
    expect(
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyR)],
      isA<TvRetryIntent>(),
    );
    expect(
      shortcuts[const SingleActivator(LogicalKeyboardKey.navigateIn)],
      isA<TvSubmitPairingIntent>(),
    );
  });

  test('TV copy describes the task instead of implementation claims', () {
    final source = File(
      '${_packageRootPrefix()}lib/main.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Screen-safe state')));
    expect(source, isNot(contains('Remote-control friendly focus')));
  });
}

Widget _localizedTvSurface({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const <Locale>[Locale('en')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AfriLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, mountedChild) => AfriLocalizationsScope(
      locale: locale,
      child: mountedChild ?? const SizedBox.shrink(),
    ),
    home: child,
  );
}

void _setTvSurface(WidgetTester tester, Size logicalSize) {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String _packageRootPrefix() {
  final current = Directory.current.path.replaceAll('\\', '/');
  return current.endsWith('/apps/rayon_sports_tv')
      ? ''
      : 'apps/rayon_sports_tv/';
}
