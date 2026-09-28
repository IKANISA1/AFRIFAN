import 'dart:ui' as ui;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_font_loader.dart';

// Golden contract: governed 720x420 captures are generated for dark and light.
enum _InteractionState { hover, focused, pressed }

typedef _TargetFinder = Finder Function(WidgetTester tester);

class _InteractionSpec {
  const _InteractionSpec({
    required this.componentKey,
    required this.builder,
    this.states = _allStates,
    this.targetFinder,
    this.focusSteps = 1,
    this.pressedPumpMs = 240,
  });

  static const _allStates = <_InteractionState>[
    _InteractionState.hover,
    _InteractionState.focused,
    _InteractionState.pressed,
  ];

  final String componentKey;
  final Widget Function(_Resources resources) builder;
  final List<_InteractionState> states;
  final _TargetFinder? targetFinder;
  final int focusSteps;
  final int pressedPumpMs;

  String get fileKey => componentKey.replaceAll('|', '_');
}

class _Resources {
  final List<TextEditingController> _controllers = [];

  TextEditingController controller([String text = 'Supporter value']) {
    final controller = TextEditingController(text: text);
    _controllers.add(controller);
    return controller;
  }

  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCoreThemeGoldenFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    for (final spec in _interactionSpecs) {
      for (final state in spec.states) {
        testWidgets('${spec.componentKey} exposes a visually distinct '
            '${state.name} state in ${brightness.name}', (tester) async {
          ColorTokens.setBrightness(brightness);
          addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
          _setSurface(tester, const Size(720, 420));
          final resources = _Resources();
          addTearDown(resources.dispose);

          await tester.pumpWidget(
            _catalogApp(
              RepaintBoundary(
                key: const ValueKey('interaction-capture'),
                child: ColoredBox(
                  color: ColorTokens.background,
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${spec.componentKey} — ${state.name}',
                          style: TypographyTokens.titleLarge(),
                        ),
                        const SizedBox(height: SpacingTokens.spacing5),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 560,
                                maxHeight: 290,
                              ),
                              child: KeyedSubtree(
                                key: const ValueKey('interaction-target'),
                                child: spec.builder(resources),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await tester.pump();

          final before = await _capturePng(tester);
          final target =
              spec.targetFinder?.call(tester) ??
              find.byKey(const ValueKey('interaction-target'));
          expect(target, findsOneWidget);

          TestGesture? gesture;
          switch (state) {
            case _InteractionState.hover:
              gesture = await tester.createGesture(
                kind: ui.PointerDeviceKind.mouse,
              );
              await gesture.addPointer(location: Offset.zero);
              await tester.pump();
              await gesture.moveTo(tester.getCenter(target));
            case _InteractionState.focused:
              for (var step = 0; step < spec.focusSteps; step++) {
                await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              }
              expect(FocusManager.instance.primaryFocus, isNotNull);
            case _InteractionState.pressed:
              gesture = await tester.startGesture(tester.getCenter(target));
          }
          await tester.pump();
          await tester.pump(
            Duration(
              milliseconds: state == _InteractionState.pressed
                  ? spec.pressedPumpMs
                  : 240,
            ),
          );

          final after = await _capturePng(tester);
          expect(
            listEquals(before, after),
            isFalse,
            reason:
                '${spec.componentKey} ${state.name} must be visually distinct.',
          );

          await expectLater(
            find.byKey(const ValueKey('interaction-capture')),
            matchesGoldenFile(
              'goldens/interactions/${spec.fileKey}_${state.name}_'
              '${brightness.name}.png',
            ),
          );

          if (gesture != null) {
            if (state == _InteractionState.pressed) {
              await gesture.up();
            } else {
              await gesture.removePointer();
            }
          }
        });
      }
    }
  }
}

final _interactionSpecs = <_InteractionSpec>[
  _InteractionSpec(
    componentKey: 'app_shell|bottom_nav',
    targetFinder: (_) => find.text('Home'),
    builder: (_) => const AfriClubBottomNav(
      currentIndex: 0,
      onTap: _intNoop,
      items: [
        AfriClubNavItem(
          label: 'Home',
          icon: AfriIcons.home,
          activeIcon: AfriIcons.home,
        ),
        AfriClubNavItem(
          label: 'Profile',
          icon: AfriIcons.profile,
          activeIcon: AfriIcons.profile,
        ),
      ],
    ),
  ),
  _InteractionSpec(
    componentKey: 'app_shell|large_screen_side_rail',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Home'),
    builder: (_) => const SizedBox(
      width: 220,
      height: 270,
      child: AfriSideRail(
        extended: true,
        selectedIndex: 0,
        onDestinationSelected: _intNoop,
        destinations: [
          AfriSideRailDestination(
            label: 'Home',
            icon: AfriIcons.home,
            selectedIcon: AfriIcons.home,
          ),
          AfriSideRailDestination(
            label: 'Profile',
            icon: AfriIcons.profile,
            selectedIcon: AfriIcons.profile,
          ),
        ],
      ),
    ),
  ),
  for (final kind in const [
    'primary',
    'secondary',
    'tertiary',
    'destructive',
    'icon_only',
    'split',
  ])
    _InteractionSpec(
      componentKey: 'buttons|$kind',
      targetFinder: (_) => kind == 'icon_only'
          ? find.byTooltip('Settings')
          : find.text(kind == 'split' ? 'Save' : _buttonLabel(kind)),
      builder: (_) => _buildButton(kind),
    ),
  for (final kind in const [
    'text',
    'number',
    'money',
    'phone',
    'email',
    'password',
    'date',
    'time',
    'search',
    'multiline',
    'otp',
  ])
    _InteractionSpec(
      componentKey: 'inputs|$kind',
      pressedPumpMs: 120,
      states: kind == 'date' || kind == 'time'
          ? _InteractionSpec._allStates
          : const [_InteractionState.hover, _InteractionState.focused],
      targetFinder: (_) => find.byType(EditableText),
      builder: (resources) => _buildInput(kind, resources),
    ),
  _InteractionSpec(
    componentKey: 'inputs|file_media_picker',
    targetFinder: (_) => find.text('Choose supporter photo'),
    builder: (_) =>
        const AfriFileMediaPicker(label: 'supporter photo', onPick: _noop),
  ),
  _InteractionSpec(
    componentKey: 'selection|checkbox',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Share match updates'),
    builder: (_) => const AfriCheckbox(
      label: 'Share match updates',
      value: false,
      onChanged: _boolNoop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'selection|radio',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Mobile Money'),
    builder: (_) => const AfriRadio<String>(
      label: 'Mobile Money',
      value: 'momo',
      groupValue: 'card',
      onChanged: _stringNoop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'selection|switch',
    pressedPumpMs: 120,
    targetFinder: (_) => find.byType(Switch),
    builder: (_) => const AfriSwitch(value: false, onChanged: _boolNoop),
  ),
  _InteractionSpec(
    componentKey: 'selection|segmented_control',
    targetFinder: (_) => find.text('Week'),
    builder: (_) => const AfriSegmentedControl(
      items: [
        AfriSegment(label: 'Week'),
        AfriSegment(label: 'Month'),
      ],
      selectedIndex: 1,
      onChanged: _intNoop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'selection|chips',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Upcoming'),
    builder: (_) => const AfriChoiceChip(
      label: Text('Upcoming'),
      selected: false,
      onSelected: _boolNoop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'selection|tabs',
    targetFinder: (_) => find.text('Overview'),
    builder: (_) => const DefaultTabController(
      length: 2,
      child: AfriTabBar(
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Activity'),
        ],
      ),
    ),
  ),
  _InteractionSpec(
    componentKey: 'selection|menus',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Choose action'),
    builder: (_) => const AfriPopupMenuButton<String>(
      tooltip: 'Choose action',
      onSelected: _stringNoop,
      itemBuilder: _menuItems,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.spacing3),
        child: Text('Choose action'),
      ),
    ),
  ),
  _InteractionSpec(
    componentKey: 'data_display|list_row',
    targetFinder: (_) => find.text('Member profile'),
    builder: (_) => const AfriListRow(
      icon: AfriIcons.profile,
      title: 'Member profile',
      subtitle: 'Verified supporter',
      onTap: _noop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'data_display|card',
    targetFinder: (_) => find.text('Open supporter card'),
    builder: (_) => const AfriSurfaceCard(
      semanticsLabel: 'Open supporter card',
      onTap: _noop,
      child: Text('Open supporter card'),
    ),
  ),
  _InteractionSpec(
    componentKey: 'data_display|activity_item',
    targetFinder: (_) => find.text('Contribution verified'),
    builder: (_) => const AfriActivityItem(
      title: 'Contribution verified',
      subtitle: 'Blue Family',
      timestamp: '18:24',
      onTap: _noop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'navigation|list_item',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Open account'),
    builder: (_) => const AfriListTile(
      leading: Icon(AfriIcons.profile),
      title: Text('Open account'),
      trailing: Icon(AfriIcons.chevronRight),
      onTap: _noop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'navigation|large_screen_breadcrumb',
    targetFinder: (_) => find.text('Members'),
    builder: (_) => const AfriBreadcrumbs(
      items: [
        AfriBreadcrumbItem(label: 'Home', onTap: _noop),
        AfriBreadcrumbItem(label: 'Members', onTap: _noop),
        AfriBreadcrumbItem(label: 'Profile'),
      ],
    ),
  ),
  _InteractionSpec(
    componentKey: 'navigation|back_button',
    targetFinder: (_) => find.byTooltip('Back'),
    builder: (_) => const AfriBackButton(onPressed: _noop),
  ),
  _InteractionSpec(
    componentKey: 'overlays|command_menu',
    focusSteps: 2,
    targetFinder: (_) => find.text('Open profile'),
    builder: (_) => const AfriCommandMenuPanel<String>(
      items: [
        AfriCommandItem(
          value: 'profile',
          label: 'Open profile',
          icon: AfriIcons.profile,
        ),
        AfriCommandItem(
          value: 'settings',
          label: 'Open settings',
          icon: AfriIcons.settings,
        ),
      ],
      onSelected: _stringValueNoop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'media|document_preview',
    targetFinder: (_) => find.text('Supporter statement'),
    builder: (_) => const AfriDocumentPreview(
      title: 'Supporter statement',
      fileType: 'pdf',
      provenanceLabel: 'Member upload',
      onOpen: _noop,
    ),
  ),
  _InteractionSpec(
    componentKey: 'security_privacy|masked_value',
    targetFinder: (_) => find.byTooltip('Reveal account number'),
    builder: (_) =>
        const AfriMaskedValue(label: 'account number', value: '1234567890'),
  ),
  _InteractionSpec(
    componentKey: 'security_privacy|reveal_control',
    targetFinder: (_) => find.byTooltip('Reveal membership ID'),
    builder: (_) =>
        const AfriMaskedValue(label: 'membership ID', value: 'RSF-24071'),
  ),
  _InteractionSpec(
    componentKey: 'security_privacy|consent_review',
    pressedPumpMs: 120,
    targetFinder: (_) => find.text('Share analytics'),
    builder: (_) => const AfriConsentReview(
      title: 'Privacy choices',
      items: [
        AfriConsentItem(
          id: 'analytics',
          title: 'Share analytics',
          description: 'Help improve supporter services.',
          accepted: false,
        ),
      ],
      onChanged: _consentNoop,
      onConfirm: _noop,
    ),
  ),
];

Widget _buildButton(String kind) {
  return switch (kind) {
    'icon_only' => const AfriIconButton(
      icon: AfriIcons.settings,
      tooltip: 'Settings',
      onTap: _noop,
    ),
    'split' => const AfriSplitButton<String>(
      label: 'Save',
      onPressed: _noop,
      itemBuilder: _menuItems,
      onSelected: _stringValueNoop,
    ),
    _ => AfriButton(
      label: _buttonLabel(kind),
      variant: switch (kind) {
        'secondary' => AfriButtonVariant.secondary,
        'tertiary' => AfriButtonVariant.ghost,
        'destructive' => AfriButtonVariant.destructive,
        _ => AfriButtonVariant.primary,
      },
      onTap: _noop,
    ),
  };
}

String _buttonLabel(String kind) => switch (kind) {
  'secondary' => 'Secondary',
  'tertiary' => 'Tertiary',
  'destructive' => 'Delete',
  _ => 'Primary',
};

Widget _buildInput(String kind, _Resources resources) {
  final value = switch (kind) {
    'number' => '24',
    'money' => '5000',
    'phone' => '+250788000111',
    'email' => 'fan@example.invalid',
    'password' => 'protected',
    'date' => '24 Jul 2026',
    'time' => '18:30',
    'search' => 'supporter',
    'multiline' => 'Short supporter note',
    'otp' => '123456',
    _ => 'Supporter value',
  };
  final controller = resources.controller(value);
  return switch (kind) {
    'number' => AfriNumberInputField(controller: controller, label: 'Number'),
    'money' => AfriMoneyInputField(
      controller: controller,
      currencySymbol: 'RWF',
    ),
    'phone' => AfriPhoneInputField(controller: controller),
    'email' => AfriEmailInputField(controller: controller),
    'password' => AfriPasswordInputField(controller: controller),
    'date' => AfriDateInputField(controller: controller, onSelected: _dateNoop),
    'time' => AfriTimeInputField(controller: controller, onSelected: _timeNoop),
    'search' => AfriSearchInputField(controller: controller),
    'multiline' => AfriInputField(
      controller: controller,
      label: 'Message',
      maxLines: 2,
    ),
    'otp' => AfriOtpInputField(controller: controller),
    _ => AfriInputField(controller: controller, label: 'Text'),
  };
}

List<PopupMenuEntry<String>> _menuItems(BuildContext context) => const [
  PopupMenuItem(value: 'profile', child: Text('Open profile')),
  PopupMenuItem(value: 'settings', child: Text('Open settings')),
];

Future<Uint8List> _capturePng(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('interaction-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }))!;
}

Widget _catalogApp(Widget child, {required Brightness brightness}) {
  const config = _InteractionConfig();
  return ClubConfigScope(
    config: config,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ClubTheme.from(config, brightness: brightness),
      home: Scaffold(body: child),
    ),
  );
}

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void _noop() {}
void _boolNoop(bool? _) {}
void _consentNoop(String _, bool __) {}
void _dateNoop(DateTime _) {}
void _intNoop(int _) {}
void _stringNoop(String? _) {}
void _stringValueNoop(String _) {}
void _timeNoop(TimeOfDay _) {}

class _InteractionConfig implements ClubConfig {
  const _InteractionConfig();

  @override
  String get appName => 'Gikundiro';
  @override
  String get clubId => '24';
  @override
  String get clubName => 'Rayon Sports FC';
  @override
  ClubColors get colors => const ClubColors(
    primary: ColorTokens.referenceAccountBlue,
    secondary: ColorTokens.referenceChromeBlack,
    accent: ColorTokens.referenceRewardsVioletHot,
    gradient: [
      ColorTokens.referenceChromeBlack,
      ColorTokens.referenceAccountBlue,
    ],
  );
  @override
  String get country => 'Rwanda';
  @override
  String get countryCode => 'RW';
  @override
  String get currency => 'RWF';
  @override
  String get currencySymbol => 'RWF';
  @override
  bool get hasChat => true;
  @override
  bool get hasFanClubs => true;
  @override
  bool get hasShop => true;
  @override
  bool get hasTicketing => true;
  @override
  String get language => 'en';
  @override
  String get momoPrefix => '*182*';
  @override
  MomoConfig get momo => const MomoConfig(
    ussdTemplate: '*182*{amount}*{momo}#',
    countryCode: 'RW',
  );
  @override
  String get supabaseAnonKey => 'synthetic';
  @override
  String get supabaseUrl => 'https://example.invalid';
  @override
  List<String> get supportedLanguages => const ['en'];
  @override
  String get environment => 'golden';
  @override
  Map<String, bool> get features => const {};
}
