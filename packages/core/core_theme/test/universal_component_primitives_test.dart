import 'dart:convert';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Size size = const Size(800, 900)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  test('numeric formatter bounds sign and decimal precision', () {
    final formatter = AfriNumericInputFormatter(
      allowDecimal: true,
      allowNegative: true,
      decimalDigits: 2,
    );
    const empty = TextEditingValue.empty;
    const valid = TextEditingValue(text: '-12.34');
    const invalid = TextEditingValue(text: '-12.345');

    expect(formatter.formatEditUpdate(empty, valid), valid);
    expect(formatter.formatEditUpdate(valid, invalid), valid);
  });

  testWidgets('money and phone presets enforce governed input contracts', (
    tester,
  ) async {
    final money = TextEditingController();
    final phone = TextEditingController();
    addTearDown(money.dispose);
    addTearDown(phone.dispose);

    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriMoneyInputField(
              controller: money,
              currencySymbol: 'RWF',
              decimalDigits: 2,
            ),
            AfriPhoneInputField(controller: phone),
          ],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '123.45');
    await tester.enterText(find.byType(TextField).at(1), '+250 788 abc 123');
    expect(money.text, '123.45');
    expect(phone.text, '+250 788  123');
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).autofillHints,
      contains(AutofillHints.telephoneNumber),
    );
  });

  testWidgets('password reveal is explicit and preserves secure defaults', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'correct horse');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        AfriPasswordInputField(controller: controller, strengthLabel: 'Strong'),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.textContaining('Strength: Strong'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('date and time presets use caller-reviewable picker results', (
    tester,
  ) async {
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    addTearDown(dateController.dispose);
    addTearDown(timeController.dispose);
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AfriDateInputField(
              controller: dateController,
              onSelected: (value) => selectedDate = value,
              picker: (context, initial, first, last) async =>
                  DateTime(2026, 7, 24),
            ),
            AfriTimeInputField(
              controller: timeController,
              onSelected: (value) => selectedTime = value,
              picker: (context, initial) async =>
                  const TimeOfDay(hour: 18, minute: 30),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(TextField).at(0));
    await tester.pump();
    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    expect(selectedDate, DateTime(2026, 7, 24));
    expect(selectedTime, const TimeOfDay(hour: 18, minute: 30));
  });

  testWidgets('OTP completes only at the governed length', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? completed;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        AfriOtpInputField(
          controller: controller,
          length: 6,
          onCompleted: (value) => completed = value,
        ),
      ),
    );

    expect(find.bySemanticsLabel('One-time code, 6 digits'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12345');
    expect(completed, isNull);
    await tester.enterText(find.byType(TextField), '1234567');
    expect(controller.text, '123456');
    expect(completed, '123456');
    semantics.dispose();
  });

  testWidgets('file/media picker exposes rights provenance and denied state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var picks = 0;
    await tester.pumpWidget(
      _app(
        AfriFileMediaPicker(
          label: 'supporter photo',
          state: AfriPickerState.permissionDenied,
          fileName: 'fan-photo.jpg',
          provenanceLabel: 'user selected',
          onPick: () => picks += 1,
        ),
      ),
    );

    expect(find.text('Source: user selected'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Warning status: Permission is required before selecting media',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Replace supporter photo'));
    expect(picks, 1);
    semantics.dispose();
  });

  testWidgets('checkbox and radio expose selection without color', (
    tester,
  ) async {
    bool? checked = false;
    String? selected = 'a';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AfriCheckbox(
                label: 'Remember preference',
                value: checked,
                onChanged: (value) => setState(() => checked = value),
              ),
              AfriRadio<String>(
                label: 'Option B',
                value: 'b',
                groupValue: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Remember preference'));
    await tester.tap(find.text('Option B'));
    await tester.pump();
    expect(checked, isTrue);
    expect(selected, 'b');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Option B')),
      matchesSemantics(
        label: 'Option B',
        hasCheckedState: true,
        isSelected: true,
        hasSelectedState: true,
        isChecked: true,
        isEnabled: true,
        hasEnabledState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('snackbar severity is announced and action is reachable', (
    tester,
  ) async {
    var actionCount = 0;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => AfriSnackbar.show(
              context,
              message: 'Connection lost',
              tone: AfriSnackbarTone.error,
              actionLabel: 'Retry',
              onAction: () => actionCount += 1,
            ),
            child: const Text('Show message'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show message'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Error: Connection lost' &&
            widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    tester.widget<SnackBar>(find.byType(SnackBar)).action!.onPressed();
    expect(actionCount, 1);
  });

  testWidgets(
    'data display primitives cover compact, empty, and receipt states',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 360,
            child: ListView(
              children: const [
                AfriTableRow(
                  cells: [
                    AfriTableCellData(label: 'Member', value: 'Aline'),
                    AfriTableCellData(
                      label: 'Private note',
                      value: 'Hidden',
                      priority: 2,
                    ),
                  ],
                ),
                AfriAvatar(semanticLabel: 'Aline', initials: 'Aline Mukamana'),
                AfriBadge(
                  label: 'Verified member',
                  kind: AfriBadgeKind.verification,
                ),
                AfriTimeline(entries: []),
                AfriReceipt(
                  title: 'Contribution',
                  lines: [
                    AfriReceiptLine(label: 'Community', value: 'Blue Family'),
                  ],
                  totalLabel: 'Total',
                  totalValue: 'RWF 5,000',
                ),
              ],
            ),
          ),
          size: const Size(360, 900),
        ),
      );

      expect(find.text('Member: Aline'), findsOneWidget);
      expect(find.textContaining('Private note'), findsNothing);
      expect(find.bySemanticsLabel('Aline avatar'), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
      await tester.ensureVisible(find.text('Contribution'));
      await tester.pump();
      expect(
        find.bySemanticsLabel(
          RegExp(r'Contribution receipt.*Total: RWF 5,000'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  testWidgets('side rail and breadcrumbs expose large-screen navigation', (
    tester,
  ) async {
    var selected = 0;
    var breadcrumbTapped = false;
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            StatefulBuilder(
              builder: (context, setState) => AfriSideRail(
                extended: true,
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                destinations: const [
                  AfriSideRailDestination(
                    label: 'Home',
                    icon: AfriIcons.home,
                    selectedIcon: AfriIcons.home,
                  ),
                  AfriSideRailDestination(
                    label: 'Settings',
                    icon: AfriIcons.settings,
                    selectedIcon: AfriIcons.settings,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AfriBreadcrumbs(
                items: [
                  AfriBreadcrumbItem(
                    label: 'Home',
                    onTap: () => breadcrumbTapped = true,
                  ),
                  const AfriBreadcrumbItem(label: 'Settings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Settings').first);
    await tester.tap(find.text('Home').last);
    expect(selected, 1);
    expect(breadcrumbTapped, isTrue);
  });

  testWidgets('popover and command menu support open, search, and selection', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AfriPopover(
                tooltip: 'More information',
                contentBuilder: (_) => const Text('Anchored details'),
              ),
              TextButton(
                onPressed: () async {
                  selected = await AfriCommandMenu.show<String>(
                    context,
                    title: 'Commands',
                    items: const [
                      AfriCommandItem(
                        value: 'open',
                        label: 'Open profile',
                        icon: AfriIcons.profile,
                      ),
                      AfriCommandItem(
                        value: 'settings',
                        label: 'Open settings',
                        icon: AfriIcons.settings,
                      ),
                    ],
                  );
                },
                child: const Text('Open commands'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More information'));
    await tester.pumpAndSettle();
    expect(find.text('Anchored details'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open commands'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'settings');
    await tester.pump();
    expect(find.text('Open profile'), findsNothing);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(selected, 'settings');
  });

  testWidgets('media surfaces fail closed and retain privacy semantics', (
    tester,
  ) async {
    final onePixelPng = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
      ),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        ListView(
          children: [
            AfriVideoThumbnail(
              image: MemoryImage(onePixelPng),
              width: 320,
              height: 180,
              semanticLabel: 'Match highlights',
              provenanceId: 'video-001',
              rightsApproved: false,
            ),
            const AfriDocumentPreview(
              title: 'Membership terms',
              fileType: 'PDF',
              provenanceLabel: 'official-club-document',
              state: AfriDocumentState.offline,
            ),
            const AfriQrBarcodeSurface(
              code: ColoredBox(key: ValueKey('raw-code'), color: Colors.black),
              semanticLabel: 'Ticket code',
              enabled: false,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Media unavailable'), findsOneWidget);
    expect(find.text('Document unavailable offline'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ticket code. Sensitive code; do not share'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('raw-code')), findsNothing);
    semantics.dispose();
  });

  testWidgets('security prompts keep permission and consent caller-owned', (
    tester,
  ) async {
    var permissionAttempts = 0;
    var consentChanges = 0;
    var confirmed = 0;
    await tester.pumpWidget(
      _app(
        ListView(
          children: [
            AfriSessionTimeoutPrompt(
              state: AfriSessionTimeoutState.expired,
              onReauthenticate: () {},
            ),
            AfriPermissionPrompt(
              title: 'Photos permission',
              reason: 'Choose one image only when you continue.',
              state: AfriPermissionState.education,
              onContinue: () => permissionAttempts += 1,
            ),
            AfriConsentReview(
              title: 'Review consent',
              items: const [
                AfriConsentItem(
                  id: 'terms',
                  title: 'Terms',
                  description: 'Required to continue',
                  accepted: false,
                  required: true,
                ),
              ],
              onChanged: (id, value) => consentChanges += 1,
              onConfirm: () => confirmed += 1,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Terms (required)'));
    await tester.tap(find.text('Confirm choices'));
    expect(permissionAttempts, 1);
    expect(consentChanges, 1);
    expect(confirmed, 0);
  });
}
