import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders all tone variants', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [
            for (final tone in AfriStateBannerTone.values)
              AfriStateBanner(
                icon: AfriIcons.statusInfo,
                title: tone.name,
                tone: tone,
              ),
          ],
        ),
      ),
    );

    for (final tone in AfriStateBannerTone.values) {
      expect(find.text(tone.name), findsOneWidget);
    }
  });

  testWidgets('combines title and subtitle in semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const AfriStateBanner(
          icon: AfriIcons.statusWarning,
          title: 'Live updates paused',
          subtitle: 'Showing the latest cached data.',
          tone: AfriStateBannerTone.warning,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Warning status: Live updates paused. Showing the latest cached data.',
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets('supports tap action and trailing fallback', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _wrap(
        AfriStateBanner(
          icon: AfriIcons.statusInfo,
          title: 'Support available',
          onTap: () => taps += 1,
        ),
      ),
    );

    expect(find.byIcon(AfriIcons.chevronRight), findsOneWidget);

    await tester.tap(find.text('Support available'));
    expect(taps, 1);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
