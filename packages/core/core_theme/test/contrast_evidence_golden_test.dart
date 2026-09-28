import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCoreThemeGoldenFonts();
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDownAll(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });

  for (final brightness in Brightness.values) {
    testWidgets('golden contrast evidence ${brightness.name}', (tester) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(430, 900));

      await tester.pumpWidget(
        _app(
          brightness,
          const RepaintBoundary(
            key: ValueKey<String>('contrast-evidence'),
            child: _ContrastEvidencePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('contrast-evidence')),
        matchesGoldenFile(
          'goldens/contrast_evidence_${brightness.name}_430x900.png',
        ),
      );
    });
  }
}

class _ContrastEvidencePage extends StatelessWidget {
  const _ContrastEvidencePage();

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final supporting = ColorTokens.accessibleMetricColor(colors.secondaryText);

    return ColoredBox(
      color: colors.appBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.spacing5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contrast evidence',
                style: TypographyTokens.headlineMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Text(
                'Measured hierarchy, overlays, inactive controls, and metrics',
                style: TypographyTokens.bodySmall(supporting),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              Container(
                padding: const EdgeInsets.all(SpacingTokens.spacing4),
                decoration: BoxDecoration(
                  color: colors.overlaySurface,
                  borderRadius: ShapeTokens.cardRadius,
                  border: Border.all(
                    color: ColorTokens.accessibleChartColor(colors.accent),
                    width: BorderTokens.standard,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overlay review',
                      style: TypographyTokens.titleMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      'Primary and supporting text remain legible on the '
                      'elevated overlay surface.',
                      style: TypographyTokens.bodySmall(supporting),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              const AfriStateBanner(
                icon: AfriIcons.offline,
                tone: AfriStateBannerTone.info,
                title: 'Network action unavailable',
                subtitle:
                    'Connect to the internet before submitting this change.',
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              const AfriButton(
                label: 'Submit unavailable',
                onTap: _noop,
                enabled: false,
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              const AfriListRow(
                icon: AfriIcons.notifications,
                title: 'Match alerts unavailable',
                subtitle: 'Enable notifications in system settings.',
                enabled: false,
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              Row(
                children: [
                  const Expanded(
                    child: AfriMetricTile(
                      label: 'Supporters',
                      value: '12,480',
                      meta: 'Updated now',
                      icon: AfriIcons.groups,
                      accentColor: ColorTokens.referenceTrophyGold,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: AfriMetricTile(
                      label: 'Success rate',
                      value: '84%',
                      meta: 'Last 30 days',
                      icon: AfriIcons.statusSuccess,
                      accentColor: ColorTokens.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contribution trend',
                      style: TypographyTokens.titleMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _SeriesLegend(
                      icon: AfriIcons.contribute,
                      label: 'Verified contributions',
                      value: '68%',
                      color: ColorTokens.primary,
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _SeriesLegend(
                      icon: AfriIcons.statusPending,
                      label: 'Pending review',
                      value: '22%',
                      color: ColorTokens.info,
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    _SeriesLegend(
                      icon: AfriIcons.warning,
                      label: 'Needs attention',
                      value: '10%',
                      color: ColorTokens.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesLegend extends StatelessWidget {
  const _SeriesLegend({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final marker = ColorTokens.accessibleChartColor(color);
    final text = ColorTokens.accessibleMetricColor(color);
    return Row(
      children: [
        Icon(icon, color: marker, size: SizeTokens.iconSm),
        const SizedBox(width: SpacingTokens.spacing2),
        Expanded(child: Text(label, style: TypographyTokens.bodySmall())),
        Text(value, style: TypographyTokens.labelLarge(text)),
      ],
    );
  }
}

Widget _app(Brightness brightness, Widget child) {
  const config = _EvidenceConfig();
  return ClubConfigScope(
    config: config,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ClubTheme.from(config, brightness: brightness),
      home: Scaffold(body: SizedBox.expand(child: child)),
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

class _EvidenceConfig implements ClubConfig {
  const _EvidenceConfig();

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
    accent: ColorTokens.referenceTrophyGold,
    gradient: <Color>[
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
  List<String> get supportedLanguages => const <String>['en'];
  @override
  String get environment => 'golden';
  @override
  Map<String, bool> get features => const <String, bool>{};
}
