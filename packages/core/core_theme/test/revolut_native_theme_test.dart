import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadCoreThemeGoldenFonts);

  setUp(() {
    ColorTokens.init();
    ColorTokens.setBrightness(Brightness.dark);
  });
  tearDown(() => ColorTokens.setBrightness(Brightness.dark));

  test(
    'light and dark control state colours remain bound to their own theme',
    () {
      final light = ClubTheme.from(
        ClubConfig.fallback(),
        brightness: Brightness.light,
      );
      final dark = ClubTheme.from(ClubConfig.fallback());

      for (final theme in [light, dark]) {
        final colors = theme.extension<AfriSemanticColors>()!;
        expect(
          theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
          colors.accent,
        );
        expect(
          theme.switchTheme.thumbColor!.resolve({}),
          ColorTokens.switchThumb,
        );
        expect(
          theme.switchTheme.trackColor!.resolve({}),
          ColorTokens.switchInactiveTrack,
        );
        expect(
          theme.radioTheme.fillColor!.resolve({WidgetState.selected}),
          colors.accent,
        );
        expect(
          theme.checkboxTheme.overlayColor!.resolve({WidgetState.focused}),
          colors.accent.withValues(alpha: 0.22),
        );
        expect(theme.colorScheme.surfaceTint, Colors.transparent);
        expect(theme.colorScheme.onSurfaceVariant, colors.secondaryText);
        expect(theme.applyElevationOverlayColor, isFalse);
      }
      expect(
        light.switchTheme.trackColor!.resolve({WidgetState.selected}),
        isNot(dark.switchTheme.trackColor!.resolve({WidgetState.selected})),
      );
    },
  );

  test(
    'pickers, menus and system handoffs inherit neutral semantic surfaces',
    () {
      for (final brightness in Brightness.values) {
        final theme = ClubTheme.from(
          ClubConfig.fallback(),
          brightness: brightness,
        );
        final colors = theme.extension<AfriSemanticColors>()!;
        expect(theme.dialogTheme.backgroundColor, colors.overlaySurface);
        expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
        expect(theme.popupMenuTheme.color, colors.overlaySurface);
        expect(
          theme.menuTheme.style!.backgroundColor!.resolve({}),
          colors.overlaySurface,
        );
        expect(theme.datePickerTheme.backgroundColor, colors.overlaySurface);
        expect(
          theme.datePickerTheme.headerBackgroundColor,
          colors.overlaySurface,
        );
        expect(
          theme.datePickerTheme.dayBackgroundColor!.resolve({
            WidgetState.selected,
          }),
          colors.accent,
        );
        expect(
          theme.datePickerTheme.todayForegroundColor!.resolve({
            WidgetState.selected,
          }),
          ColorTokens.contrastForeground(colors.accent),
        );
        expect(theme.timePickerTheme.backgroundColor, colors.overlaySurface);
        expect(theme.timePickerTheme.dialHandColor, colors.accent);
        expect(
          theme.bottomSheetTheme.modalBarrierColor,
          theme.colorScheme.scrim,
        );
        expect(
          theme.cupertinoOverrideTheme!.scaffoldBackgroundColor,
          colors.appBackground,
        );
        expect(theme.cupertinoOverrideTheme!.primaryColor, colors.accent);
        expect(
          theme.cupertinoOverrideTheme!.textTheme!.navActionTextStyle.color,
          colors.accent,
        );
        expect(theme.textSelectionTheme.cursorColor, colors.accent);
      }
    },
  );

  testWidgets('the iOS control bridge keeps the selected product roles', (
    tester,
  ) async {
    final theme = ClubTheme.from(
      ClubConfig.fallback(),
      brightness: Brightness.light,
    ).copyWith(platform: TargetPlatform.iOS);
    late CupertinoThemeData resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            resolved = CupertinoTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      resolved.primaryColor,
      theme.extension<AfriSemanticColors>()!.accent,
    );
    expect(resolved.brightness, Brightness.light);
    expect(
      resolved.textTheme.navActionTextStyle.color,
      theme.extension<AfriSemanticColors>()!.accent,
    );
  });

  testWidgets('compact enlarged labels keep words and actions readable', (
    tester,
  ) async {
    TypographyTokens.debugUseFallbackFonts = true;
    addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ClubTheme.from(ClubConfig.fallback()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing6,
            ),
            child: AfriListRow(
              icon: AfriIcons.membership,
              title: 'Membership details',
              onTap: () => taps += 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Membership details'),
    );
    expect(
      paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 10),
      ),
      hasLength(1),
      reason: 'The icon/chevron gutters must not split Membership mid-word.',
    );
    await tester.tap(find.text('Membership details'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  for (final variant in [
    (width: 390.0, scale: 1.0, brightness: Brightness.dark),
    (width: 320.0, scale: 2.0, brightness: Brightness.dark),
    (width: 390.0, scale: 1.0, brightness: Brightness.light),
  ]) {
    testWidgets(
      'settings controls preserve states at ${variant.width} and ${variant.scale} ${variant.brightness.name}',
      (tester) async {
        TypographyTokens.debugUseFallbackFonts = true;
        addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
        tester.view.physicalSize = Size(variant.width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var enabledTaps = 0;
        final theme = ClubTheme.from(
          ClubConfig.fallback(),
          brightness: variant.brightness,
        ).copyWith(platform: TargetPlatform.iOS);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(variant.scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundaryKey,
              child: AfriScreenScaffold(
                title: 'Settings',
                showBackButton: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AfriSurfaceCard(
                      child: Column(
                        children: [
                          AfriSwitchListTile(
                            value: true,
                            onChanged: (_) => enabledTaps += 1,
                            title: const Text('Notifications'),
                            subtitle: const Text('Club updates and match news'),
                          ),
                          AfriSwitchListTile(
                            value: false,
                            onChanged: (_) => enabledTaps += 1,
                            title: const Text('Match reminders'),
                            subtitle: const Text(
                              'Choose reminders in settings',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    const AfriSurfaceCard(
                      child: AfriSwitchListTile(
                        value: false,
                        onChanged: null,
                        title: Text('Push notifications'),
                        subtitle: Text('Permission is unavailable'),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AfriSwitch(
                        semanticsLabel: 'Push notifications',
                        value: false,
                        onChanged: (_) => enabledTaps += 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final switchWidget = tester.widget<Switch>(
          find.descendant(
            of: find.byType(AfriSwitch),
            matching: find.byType(Switch),
          ),
        );
        expect(switchWidget.inactiveThumbColor, ColorTokens.switchThumb);
        expect(
          switchWidget.inactiveTrackColor,
          ColorTokens.switchInactiveTrack,
        );
        expect(
          switchWidget.activeTrackColor,
          theme.extension<AfriSemanticColors>()!.accent,
        );
        final captureDir = Platform.environment['AFRI_DESIGN_CAPTURE_DIR'];
        if (captureDir?.isNotEmpty == true) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '$captureDir/native-settings-${variant.brightness.name}-${variant.width.toInt()}-${(variant.scale * 100).round()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.byType(AfriSwitch));
        await tester.tap(find.byType(AfriSwitch));
        await tester.pumpAndSettle();
        expect(enabledTaps, 1);
        await tester.ensureVisible(find.text('Push notifications'));
        await tester.tap(find.text('Push notifications'));
        await tester.pumpAndSettle();
        expect(enabledTaps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
