import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_contributions/src/widgets/overlays/momo_contribution_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'contribution payment updates are live and recovery control remains reachable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const MaterialApp(home: _StatusHarness()));

      expect(
        find.bySemanticsLabel(
          'AWAITING PAYMENT. Complete the MoMo payment on your phone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Simulate failure'));
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          'PAYMENT FAILED. Check your MoMo balance and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Back to group'), findsOneWidget);
      await tester.ensureVisible(find.text('Back to group'));
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      semantics.dispose();
    },
  );

  testWidgets('amount draft survives confirmation back and cancellation', (
    tester,
  ) async {
    final previousCountries = AfriCountryCatalog.all;
    AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
    addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ClubConfigScope(
          config: ClubConfig.fallback(),
          child: const _ContributionFlowHarness(),
        ),
      ),
    );

    await tester.tap(find.text('Open contribution'));
    await tester.pumpAndSettle();
    final amountChip = find.ancestor(
      of: find.text('+10K'),
      matching: find.byType(AfriChoiceChip),
    );
    await tester.ensureVisible(amountChip);
    await tester.tap(amountChip);
    await tester.pump();
    final launch = find.text('Launch MOMO dialer');
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pumpAndSettle();

    expect(find.textContaining('10000'), findsWidgets);
    await tester.tap(find.text('Change amount'));
    await tester.pumpAndSettle();

    final selectedAmount = tester.widget<AfriChoiceChip>(
      find.ancestor(
        of: find.text('+10K'),
        matching: find.byType(AfriChoiceChip),
      ),
    );
    expect(selectedAmount.selected, isTrue);

    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel contribution'));
    await tester.pumpAndSettle();

    expect(find.text('Contribution flow idle'), findsOneWidget);
    expect(find.text('HOW MUCH TO CONTRIBUTE?'), findsNothing);
    expect(find.text('LAUNCHING MOMO'), findsNothing);
  });

  testWidgets(
    'keyboard-open compact viewport keeps contribution choices and actions reachable',
    (tester) async {
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const _ContributionFlowHarness(),
          ),
        ),
      );

      await tester.tap(find.text('Open contribution'));
      await tester.pumpAndSettle();
      final amountChip = find.ancestor(
        of: find.text('+10K'),
        matching: find.byType(AfriChoiceChip),
      );
      await tester.ensureVisible(amountChip);
      await tester.tap(amountChip);
      final launch = find.widgetWithText(AfriButton, 'Launch MOMO dialer');
      await tester.ensureVisible(launch);
      await tester.pumpAndSettle();
      _expectInKeyboardViewport(tester, amountChip);
      _expectInKeyboardViewport(tester, launch);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '200 percent text keeps populated contribution sheets scrollable',
    (tester) async {
      final previousCountries = AfriCountryCatalog.all;
      AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
      addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: ClubConfigScope(
            config: ClubConfig.fallback(),
            child: const _ContributionFlowHarness(),
          ),
        ),
      );

      await tester.tap(find.text('Open contribution'));
      await tester.pumpAndSettle();
      final amountChip = find.ancestor(
        of: find.text('+10K'),
        matching: find.byType(AfriChoiceChip),
      );
      await tester.ensureVisible(amountChip);
      await tester.tap(amountChip);
      final launch = find.widgetWithText(AfriButton, 'Launch MOMO dialer');
      await tester.ensureVisible(launch);
      expect(tester.takeException(), isNull);

      await tester.tap(launch);
      await tester.pumpAndSettle();
      expect(find.textContaining('10000'), findsWidgets);
      final change = find.widgetWithText(AfriButton, 'Change amount');
      final dial = find.widgetWithText(AfriButton, 'Dial now');
      final cancel = find.text('Cancel contribution');
      await tester.ensureVisible(change);
      await tester.ensureVisible(dial);
      await tester.ensureVisible(cancel);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in <String, Size>{
    'standard landscape': const Size(852, 393),
    'compact-height landscape': const Size(720, 320),
  }.entries) {
    testWidgets(
      '${profile.key} keeps contribution sheet choices and actions usable',
      (tester) async {
        final previousCountries = AfriCountryCatalog.all;
        AfriCountryCatalog.withCountries(const <AfriCountry>[_rwanda]);
        addTearDown(() => AfriCountryCatalog.withCountries(previousCountries));
        tester.view.physicalSize = profile.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: ClubConfigScope(
              config: ClubConfig.fallback(),
              child: const _ContributionFlowHarness(),
            ),
          ),
        );

        await tester.tap(find.text('Open contribution'));
        await tester.pumpAndSettle();
        final amountChip = find.ancestor(
          of: find.text('+10K'),
          matching: find.byType(AfriChoiceChip),
        );
        await tester.ensureVisible(amountChip);
        await tester.tap(amountChip);
        final launch = find.widgetWithText(AfriButton, 'Launch MOMO dialer');
        await tester.ensureVisible(launch);
        await tester.tap(launch);
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.widgetWithText(AfriButton, 'Change amount'),
        );
        await tester.ensureVisible(find.widgetWithText(AfriButton, 'Dial now'));
        await tester.ensureVisible(find.text('Cancel contribution'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _expectInKeyboardViewport(WidgetTester tester, Finder finder) {
  final visibleBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
      tester.view.viewInsets.bottom;
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
}

class _StatusHarness extends StatefulWidget {
  const _StatusHarness();

  @override
  State<_StatusHarness> createState() => _StatusHarnessState();
}

class _StatusHarnessState extends State<_StatusHarness> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final heading = _failed ? 'PAYMENT FAILED' : 'AWAITING PAYMENT';
    final message = _failed
        ? 'Check your MoMo balance and try again.'
        : 'Complete the MoMo payment on your phone.';

    return Scaffold(
      body: SingleChildScrollView(
        child: ContributionPaymentStatusAnnouncement(
          heading: heading,
          message: message,
          child: Column(
            children: <Widget>[
              Text(heading),
              Text(message),
              AfriTextButton(
                onPressed: () {},
                child: const Text('Back to group'),
              ),
              AfriButton(
                label: 'Simulate failure',
                onTap: () => setState(() => _failed = true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContributionFlowHarness extends StatelessWidget {
  const _ContributionFlowHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const Text('Contribution flow idle'),
          AfriButton(
            label: 'Open contribution',
            onTap: () async {
              await showMomoAmountEntrySheet(
                context,
                title: 'Support the club',
                recipientMomo: '1828',
              );
            },
          ),
        ],
      ),
    );
  }
}

const _rwanda = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: '',
  currencyCode: 'RWF',
  currencyName: 'Rwandan franc',
  momoUssdTemplate: '*182*1*1*{recipient}*{amount}#',
  momoCodeUssdTemplate: '*182*8*1*{recipient}*{amount}#',
);
