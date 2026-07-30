import 'dart:async';
import 'dart:io';

import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayon_sports_tv/main.dart';

const _config = RayonSportsConfig();
const _goldenKey = ValueKey<String>('tv-route-state-golden');
const _displayState = TvDisplayState(
  venueName: 'Kigali Arena',
  sessionCode: 'SCREEN24',
  expiresAt: '21:45',
  fetReward: 25,
  prompt: 'Join from the supporter app.',
  phase: 'Open',
);

const _goldens = <String, String>{
  'loading': 'goldens/tv_session_state_loading_dark_1280x720.png',
  'empty': 'goldens/tv_session_state_empty_dark_1280x720.png',
  'error': 'goldens/tv_session_state_error_dark_1280x720.png',
  'offline': 'goldens/tv_session_state_offline_dark_1280x720.png',
  'permission_denied':
      'goldens/tv_session_state_permission_denied_dark_1280x720.png',
  'disabled': 'goldens/tv_session_state_disabled_dark_1280x720.png',
  'focused': 'goldens/tv_session_state_focused_dark_1280x720.png',
  'pressed': 'goldens/tv_session_state_pressed_dark_1280x720.png',
  'selected': 'goldens/tv_session_state_selected_dark_1280x720.png',
  'large_text': 'goldens/tv_session_state_large_text_dark_1280x720.png',
  'reduced_motion': 'goldens/tv_session_state_reduced_motion_dark_1280x720.png',
  'dark': 'goldens/tv_session_state_dark_dark_1280x720.png',
  'light': 'goldens/tv_session_state_light_light_1280x720.png',
  'syncing': 'goldens/tv_session_state_syncing_dark_1280x720.png',
  'conflict': 'goldens/tv_session_state_conflict_dark_1280x720.png',
  'security_timeout':
      'goldens/tv_session_state_security_timeout_dark_1280x720.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadGoldenRoboto);

  testWidgets('golden TV session loading state', (tester) async {
    await _pumpState(
      tester,
      const RayonSportsTvScreen(
        state: TvDisplayState.unpaired,
        connectionState: TvConnectionState.connecting,
      ),
    );
    expect(find.text('Connecting'), findsOneWidget);
    await _matchState(tester, 'loading');
  });

  testWidgets('golden TV session empty pairing state', (tester) async {
    await _pumpState(
      tester,
      TvPairingScreen(
        state: TvConnectionState.unpaired,
        onPair: (_) async => null,
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('Pair this TV'), findsOneWidget);
    await _matchState(tester, 'empty');
  });

  testWidgets('golden TV session error state', (tester) async {
    await _pumpState(
      tester,
      RayonSportsTvScreen(
        state: TvDisplayState.unpaired,
        connectionState: TvConnectionState.serviceUnavailable,
        onRetry: () {},
      ),
    );
    expect(find.text('Connection lost — retry'), findsOneWidget);
    await _matchState(tester, 'error');
  });

  testWidgets('golden TV session offline retained state', (tester) async {
    await _pumpState(
      tester,
      RayonSportsTvScreen(
        state: const TvDisplayState(
          venueName: 'Kigali Arena',
          sessionCode: 'SCREEN24',
          expiresAt: '21:45',
          fetReward: 25,
          prompt: 'Connection is offline. Confirm current details after retry.',
          phase: 'Offline',
        ),
        connectionState: TvConnectionState.serviceUnavailable,
        onRetry: () {},
      ),
    );
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('SCREEN24'), findsOneWidget);
    await _matchState(tester, 'offline');
  });

  testWidgets('golden TV session permission-denied state', (tester) async {
    await _pumpState(
      tester,
      TvPairingScreen(
        state: TvConnectionState.revoked,
        onPair: (_) async => null,
      ),
    );
    expect(find.text('Pair this TV'), findsOneWidget);
    await _matchState(tester, 'permission_denied');
  });

  testWidgets('golden TV session disabled configuration state', (tester) async {
    await _pumpState(
      tester,
      TvPairingScreen(
        state: TvConnectionState.configurationMissing,
        onPair: (_) async => null,
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('tv-pairing-code-input')),
      findsNothing,
    );
    await _matchState(tester, 'disabled');
  });

  testWidgets('golden TV session focused state', (tester) async {
    await _pumpPairing(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'TV pairing code');
    await _matchState(tester, 'focused');
  });

  testWidgets('golden TV session pressed state', (tester) async {
    await _pumpPairing(tester);
    final input = find.byKey(const ValueKey<String>('tv-pairing-code-input'));
    await tester.enterText(input, 'ABC123');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final button = find.byKey(
      const ValueKey<String>('tv-pairing-submit-button'),
    );
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 80));
    await _matchState(tester, 'pressed');
    await gesture.up();
  });

  testWidgets('golden TV session selected code state', (tester) async {
    await _pumpPairing(tester);
    final input = find.byKey(const ValueKey<String>('tv-pairing-code-input'));
    await tester.enterText(input, 'ABC123');
    final textField = tester.widget<TextField>(
      find.descendant(of: input, matching: find.byType(TextField)),
    );
    textField.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();
    expect(textField.controller!.selection.textInside('ABC123'), 'ABC123');
    await _matchState(tester, 'selected');
  });

  testWidgets('golden TV session large-text state', (tester) async {
    await _pumpState(
      tester,
      TvPairingScreen(
        state: TvConnectionState.revoked,
        onPair: (_) async => null,
      ),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
    await _matchState(tester, 'large_text');
  });

  testWidgets('golden TV session reduced-motion state', (tester) async {
    await _pumpState(
      tester,
      TvPairingScreen(
        state: TvConnectionState.unpaired,
        onPair: (_) async => null,
      ),
      disableAnimations: true,
    );
    final buttonAnimations = tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: find.byType(AfriButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      buttonAnimations.every((widget) => widget.duration == Duration.zero),
      isTrue,
    );
    await _matchState(tester, 'reduced_motion');
  });

  testWidgets('golden TV session dark state', (tester) async {
    await _pumpState(tester, const RayonSportsTvScreen(state: _displayState));
    expect(
      Theme.of(tester.element(find.byType(RayonSportsTvScreen))).brightness,
      Brightness.dark,
    );
    await _matchState(tester, 'dark');
  });

  testWidgets('golden TV session light state', (tester) async {
    await _pumpState(
      tester,
      const RayonSportsTvScreen(state: _displayState),
      brightness: Brightness.light,
    );
    expect(
      Theme.of(tester.element(find.byType(RayonSportsTvScreen))).brightness,
      Brightness.light,
    );
    await _matchState(tester, 'light');
  });

  testWidgets('golden TV session syncing state', (tester) async {
    final gate = Completer<String?>();
    await _pumpPairing(tester, onPair: (_) => gate.future);
    final input = find.byKey(const ValueKey<String>('tv-pairing-code-input'));
    await tester.enterText(input, 'ABC123');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.text('Pairing…'), findsOneWidget);
    await _matchState(tester, 'syncing');
    gate.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('golden TV session conflict state', (tester) async {
    await _pumpPairing(
      tester,
      onPair: (_) async =>
          'That code was already used. Request a new code and retry.',
    );
    await _submitPairing(tester);
    expect(find.textContaining('already used'), findsOneWidget);
    await _matchState(tester, 'conflict');
  });

  testWidgets('golden TV session security-timeout state', (tester) async {
    await _pumpState(
      tester,
      RayonSportsTvScreen(
        state: _displayState,
        connectionState: TvConnectionState.securityTimeout,
        onRetry: () {},
      ),
    );
    expect(find.text('Refresh timed out — retry'), findsOneWidget);
    await _matchState(tester, 'security_timeout');
  });

  for (final locale in const <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ]) {
    testWidgets(
      'localized full TV session ${locale.languageCode} fits at 720p and 200 percent text',
      (tester) async {
        TypographyTokens.debugUseFallbackFonts = true;
        addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
        final l10n = lookupAfriLocalizations(locale);
        await _pumpState(
          tester,
          const RayonSportsTvScreen(
            state: TvDisplayState(
              venueName: 'Kigali Arena',
              sessionCode: 'SCREEN24',
              expiresAt: '21:45',
              fetReward: 25,
              prompt: '',
              phase: '',
            ),
          ),
          textScaler: const TextScaler.linear(2),
          appLocale: locale,
        );

        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(_goldenKey),
          matchesGoldenFile(
            'goldens/tv_locale_${locale.languageCode}_session_large_text_1280x720.png',
          ),
        );

        final finalSafetyLabel = find.text(l10n.tvPairingStatusAndExpiry);
        await tester.ensureVisible(finalSafetyLabel);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(finalSafetyLabel).dy,
          lessThanOrEqualTo(720),
        );
      },
    );
  }
}

Future<void> _pumpPairing(
  WidgetTester tester, {
  Future<String?> Function(String code)? onPair,
}) {
  return _pumpState(
    tester,
    TvPairingScreen(
      state: TvConnectionState.unpaired,
      onPair: onPair ?? (_) async => null,
    ),
  );
}

Future<void> _submitPairing(WidgetTester tester) async {
  final input = find.byKey(const ValueKey<String>('tv-pairing-code-input'));
  await tester.enterText(input, 'ABC123');
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pumpAndSettle();
}

Future<void> _pumpState(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  Locale appLocale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

  ColorTokens.init(_config.colors);
  ColorTokens.setBrightness(brightness);
  await tester.pumpWidget(
    MaterialApp(
      theme: ClubTheme.from(_config, brightness: brightness),
      locale: appLocale.languageCode == 'rw' ? const Locale('en') : appLocale,
      supportedLocales: const <Locale>[Locale('en'), Locale('fr')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AfriLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, mountedChild) => AfriLocalizationsScope(
        locale: appLocale,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: disableAnimations,
            accessibleNavigation: disableAnimations,
          ),
          child: mountedChild ?? const SizedBox.shrink(),
        ),
      ),
      home: RepaintBoundary(key: _goldenKey, child: child),
    ),
  );
  await tester.pump();
}

Future<void> _matchState(WidgetTester tester, String id) async {
  expect(tester.takeException(), isNull);
  await expectLater(find.byKey(_goldenKey), matchesGoldenFile(_goldens[id]!));
}

Future<void> _loadGoldenRoboto() async {
  final loader = FontLoader('GoldenRoboto');
  loader.addFont(_loadGoldenRobotoBytes());
  await loader.load();
}

Future<ByteData> _loadGoldenRobotoBytes() async {
  const assetPath = 'packages/flutter/fonts/Roboto-Regular.ttf';
  try {
    return await rootBundle.load(assetPath);
  } catch (_) {
    final candidates = <File>[
      File(
        '/Volumes/PRO-G40/flutter_3_44/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
      if ((Platform.environment['FLUTTER_ROOT'] ?? '').isNotEmpty)
        File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return ByteData.sublistView(await candidate.readAsBytes());
      }
    }
    throw FileSystemException('Unable to locate Roboto-Regular.ttf');
  }
}
