import 'dart:convert';
import 'dart:typed_data';

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

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    final themeName = brightness.name;

    testWidgets('golden universal form and data component catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(900, 1600));
      final controllers = List.generate(
        8,
        (index) => TextEditingController(
          text: switch (index) {
            0 => '24',
            1 => '5,000',
            2 => '+250 788 000 111',
            3 => 'supporter@example.invalid',
            4 => 'protected',
            5 => '24 Jul 2026',
            6 => '18:30',
            _ => '123456',
          },
        ),
      );
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-form-data-catalog'),
            child: _CatalogPage(
              title: 'Universal forms and data',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          AfriNumberInputField(
                            controller: controllers[0],
                            label: 'Quantity',
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriMoneyInputField(
                            controller: controllers[1],
                            currencySymbol: 'RWF',
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriPhoneInputField(controller: controllers[2]),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriEmailInputField(controller: controllers[3]),
                        ],
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing5),
                    Expanded(
                      child: Column(
                        children: [
                          AfriPasswordInputField(
                            controller: controllers[4],
                            strengthLabel: 'Strong',
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriDateInputField(
                            controller: controllers[5],
                            onSelected: (_) {},
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriTimeInputField(
                            controller: controllers[6],
                            onSelected: (_) {},
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriOtpInputField(controller: controllers[7]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                const Row(
                  children: [
                    Expanded(
                      child: AfriCheckbox(
                        label: 'Remember preference',
                        subtitle: 'Selected state',
                        value: true,
                        onChanged: null,
                      ),
                    ),
                    SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: AfriRadio<String>(
                        label: 'Primary option',
                        value: 'primary',
                        groupValue: 'primary',
                        onChanged: null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                AfriFileMediaPicker(
                  label: 'supporter photo',
                  state: AfriPickerState.warning,
                  fileName: 'fan-photo.jpg',
                  provenanceLabel: 'user selected',
                  onPick: () {},
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                const AfriTableRow(
                  cells: [
                    AfriTableCellData(label: 'Member', value: 'Aline'),
                    AfriTableCellData(label: 'Role', value: 'Supporter'),
                    AfriTableCellData(
                      label: 'Balance',
                      value: 'RWF 5,000',
                      numeric: true,
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                const Row(
                  children: [
                    AfriAvatar(
                      semanticLabel: 'Aline Mukamana',
                      initials: 'Aline Mukamana',
                      size: 64,
                    ),
                    SizedBox(width: SpacingTokens.spacing4),
                    AfriBadge(
                      label: 'Verified member',
                      kind: AfriBadgeKind.verification,
                    ),
                    SizedBox(width: SpacingTokens.spacing3),
                    AfriBadge(
                      label: 'Matchday streak',
                      kind: AfriBadgeKind.achievement,
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                const AfriTimeline(
                  entries: [
                    AfriTimelineEntry(
                      title: 'Contribution verified',
                      timestamp: '18:24',
                      description: 'Blue Family community',
                      tone: AfriStatusTone.success,
                    ),
                    AfriTimelineEntry(
                      title: 'Receipt available',
                      timestamp: '18:25',
                      tone: AfriStatusTone.info,
                    ),
                  ],
                ),
                const AfriReceipt(
                  title: 'Contribution receipt',
                  lines: [
                    AfriReceiptLine(label: 'Community', value: 'Blue Family'),
                    AfriReceiptLine(label: 'Amount', value: 'RWF 5,000'),
                  ],
                  totalLabel: 'Total',
                  totalValue: 'RWF 5,000',
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-form-data-catalog')),
        matchesGoldenFile(
          'goldens/universal_form_data_catalog_900x1600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets(
      'golden universal navigation media and security catalog $themeName',
      (tester) async {
        ColorTokens.setBrightness(brightness);
        addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
        _setSurface(tester, const Size(900, 1600));
        final imageBytes = Uint8List.fromList(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
          ),
        );

        await tester.pumpWidget(
          _catalogApp(
            RepaintBoundary(
              key: const ValueKey('universal-media-security-catalog'),
              child: _CatalogPage(
                title: 'Navigation, media, and trust',
                children: [
                  const AfriBreadcrumbs(
                    items: [
                      AfriBreadcrumbItem(label: 'Home'),
                      AfriBreadcrumbItem(label: 'Membership'),
                      AfriBreadcrumbItem(label: 'Receipt'),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 330,
                        child: AfriSideRail(
                          extended: true,
                          selectedIndex: 0,
                          onDestinationSelected: (_) {},
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
                      const SizedBox(width: SpacingTokens.spacing5),
                      Expanded(
                        child: Column(
                          children: [
                            AfriVideoThumbnail(
                              image: MemoryImage(imageBytes),
                              width: 560,
                              height: 260,
                              semanticLabel: 'Match highlights',
                              provenanceId: 'catalog-video',
                              rightsApproved: false,
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            const AfriDocumentPreview(
                              title: 'Membership terms',
                              fileType: 'PDF',
                              provenanceLabel: 'official club document',
                              state: AfriDocumentState.offline,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AfriQrBarcodeSurface(
                          code: ColoredBox(
                            color: ColorTokens.onSurface,
                            child: const Center(
                              child: Icon(
                                AfriIcons.qrCode,
                                size: 180,
                                color: ColorTokens.referenceChromeBlack,
                              ),
                            ),
                          ),
                          semanticLabel: 'Synthetic ticket code',
                          helperText: 'Present only to an authorized scanner',
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing5),
                      const Expanded(
                        child: Column(
                          children: [
                            AfriSessionTimeoutPrompt(
                              state: AfriSessionTimeoutState.warning,
                              remaining: Duration(minutes: 2),
                              onReauthenticate: _noop,
                            ),
                            SizedBox(height: SpacingTokens.spacing4),
                            AfriPermissionPrompt(
                              title: 'Photos permission',
                              reason:
                                  'Choose one image only when you continue.',
                              state: AfriPermissionState.education,
                              onContinue: _noop,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriConsentReview(
                    title: 'Review consent',
                    items: const [
                      AfriConsentItem(
                        id: 'terms',
                        title: 'Terms',
                        description: 'Required to continue',
                        accepted: true,
                        required: true,
                      ),
                      AfriConsentItem(
                        id: 'analytics',
                        title: 'Product analytics',
                        description: 'Optional and off by default',
                        accepted: false,
                      ),
                    ],
                    onChanged: (_, _) {},
                    onConfirm: () {},
                  ),
                ],
              ),
            ),
            brightness: brightness,
          ),
        );
        await tester.pump();

        await expectLater(
          find.byKey(const ValueKey('universal-media-security-catalog')),
          matchesGoldenFile(
            'goldens/universal_media_security_catalog_900x1600'
            '${brightness == Brightness.light ? '_light' : ''}.png',
          ),
        );
      },
    );

    testWidgets('golden universal interactive state catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(900, 1600));

      await tester.pumpWidget(
        _catalogApp(
          const RepaintBoundary(
            key: ValueKey('universal-interactive-state-catalog'),
            child: _CatalogPage(
              title: 'Interactive and feedback states',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Button emphasis'),
                          AfriButton(
                            label: 'Primary action',
                            icon: AfriIcons.check,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            label: 'Secondary action',
                            variant: AfriButtonVariant.secondary,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            label: 'Tertiary action',
                            variant: AfriButtonVariant.ghost,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            label: 'Delete record',
                            variant: AfriButtonVariant.destructive,
                            icon: AfriIcons.delete,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            label: 'Saving',
                            isLoading: true,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            label: 'Unavailable',
                            enabled: false,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          _CatalogLabel('Selection'),
                          AfriCheckbox(
                            label: 'Selected checkbox',
                            value: true,
                            onChanged: _boolNoop,
                          ),
                          AfriCheckbox(
                            label: 'Default checkbox',
                            value: false,
                            onChanged: _boolNoop,
                          ),
                          AfriCheckbox(
                            label: 'Disabled checkbox',
                            value: false,
                            onChanged: null,
                          ),
                          AfriRadio<String>(
                            label: 'Selected radio',
                            value: 'selected',
                            groupValue: 'selected',
                            onChanged: _stringNoop,
                          ),
                          AfriRadio<String>(
                            label: 'Default radio',
                            value: 'option',
                            groupValue: 'other',
                            onChanged: _stringNoop,
                          ),
                          Row(
                            children: [
                              Expanded(child: Text('Enabled switch')),
                              AfriSwitch(
                                semanticsLabel: 'Enabled switch',
                                value: true,
                                onChanged: _boolNoop,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(child: Text('Default switch')),
                              AfriSwitch(
                                semanticsLabel: 'Default switch',
                                value: false,
                                onChanged: _boolNoop,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(child: Text('Disabled switch')),
                              AfriSwitch(
                                semanticsLabel: 'Disabled switch',
                                value: false,
                                onChanged: null,
                              ),
                            ],
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSegmentedControl(
                            items: [
                              AfriSegment(label: 'Live'),
                              AfriSegment(label: 'Upcoming'),
                              AfriSegment(label: 'Locked'),
                            ],
                            selectedIndex: 0,
                            disabledIndices: {2},
                            onChanged: _intNoop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          Wrap(
                            spacing: SpacingTokens.spacing2,
                            children: [
                              AfriChoiceChip(
                                label: Text('Selected'),
                                selected: true,
                                onSelected: _boolNoop,
                              ),
                              AfriChoiceChip(
                                label: Text('Default'),
                                selected: false,
                                onSelected: _boolNoop,
                              ),
                              AfriChoiceChip(
                                label: Text('Disabled'),
                                selected: false,
                              ),
                            ],
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          _CatalogLabel('Picker defaults'),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            onPick: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            enabled: false,
                            onPick: _noop,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: SpacingTokens.spacing5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Feedback'),
                          AfriStateBanner(
                            icon: AfriIcons.statusInfo,
                            title: 'Default information',
                          ),
                          SizedBox(height: SpacingTokens.spacing2),
                          AfriStateBanner(
                            icon: AfriIcons.statusLoading,
                            title: 'Loading latest data',
                            tone: AfriStateBannerTone.info,
                          ),
                          SizedBox(height: SpacingTokens.spacing2),
                          AfriStateBanner(
                            icon: AfriIcons.statusSuccess,
                            title: 'Changes saved',
                            tone: AfriStateBannerTone.success,
                          ),
                          SizedBox(height: SpacingTokens.spacing2),
                          AfriStateBanner(
                            icon: AfriIcons.statusWarning,
                            title: 'Review required',
                            tone: AfriStateBannerTone.warning,
                          ),
                          SizedBox(height: SpacingTokens.spacing2),
                          AfriStateBanner(
                            icon: AfriIcons.statusError,
                            title: 'Action failed',
                            tone: AfriStateBannerTone.danger,
                          ),
                          SizedBox(height: SpacingTokens.spacing2),
                          AfriStateBanner(
                            icon: AfriIcons.offline,
                            title: 'You are offline',
                            tone: AfriStateBannerTone.warning,
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          _CatalogLabel('Data and navigation'),
                          AfriListRow(
                            icon: AfriIcons.profile,
                            title: 'Member profile',
                            subtitle: 'Interactive list row',
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSurfaceCard(
                            semanticsLabel: 'Open match card',
                            onTap: _noop,
                            child: Text('Interactive surface card'),
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriActivityItem(
                            title: 'Contribution verified',
                            subtitle: 'Blue Family',
                            timestamp: '18:24',
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriListRow(
                            icon: AfriIcons.lock,
                            title: 'Unavailable member row',
                            enabled: false,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSurfaceCard(
                            enabled: false,
                            onTap: _noop,
                            child: Text('Unavailable surface card'),
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriActivityItem(
                            title: 'Unavailable activity',
                            timestamp: '18:25',
                            enabled: false,
                            onTap: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AfriIconButton(
                                icon: AfriIcons.settings,
                                tooltip: 'Settings',
                                onTap: _noop,
                              ),
                              AfriIconButton(
                                icon: AfriIcons.settings,
                                tooltip: 'Settings unavailable',
                              ),
                              AfriBackButton(onPressed: _noop),
                              AfriBackButton(enabled: false),
                            ],
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          AfriMetricTile(
                            label: 'Members',
                            value: '24,071',
                            meta: 'Verified supporter records',
                            icon: AfriIcons.members,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriTimeline(entries: []),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-interactive-state-catalog')),
        matchesGoldenFile(
          'goldens/universal_interactive_state_catalog_900x1600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal async state catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(900, 1600));

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-async-state-catalog'),
            child: _CatalogPage(
              title: 'Async, recovery, and trust states',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _CatalogLabel('Section recovery'),
                          AfriStateView.loading(compact: true),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriEmptyView(
                            title: 'No results',
                            message: 'Try another search.',
                            compact: true,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriErrorView(
                            message: 'Offline. Reconnect and retry.',
                            icon: AfriIcons.offline,
                            compact: true,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriErrorView(
                            message: 'Try again safely.',
                            compact: true,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriStateView.success(
                            title: 'Complete',
                            message: 'Your change was saved.',
                            compact: true,
                          ),
                          const SizedBox(height: SpacingTokens.spacing5),
                          const _CatalogLabel('Progress and skeleton'),
                          const Center(child: AfriLoadingIndicator()),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriLinearProgressIndicator(value: 0.62),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriSkeleton.listCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing5),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Picker recovery'),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            state: AfriPickerState.loading,
                            onPick: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            state: AfriPickerState.success,
                            fileName: 'fan-photo.jpg',
                            provenanceLabel: 'user selected',
                            onPick: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            state: AfriPickerState.error,
                            onPick: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            state: AfriPickerState.offline,
                            onPick: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriFileMediaPicker(
                            label: 'supporter photo',
                            state: AfriPickerState.permissionDenied,
                            onPick: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          _CatalogLabel('Permission and session'),
                          AfriPermissionPrompt(
                            title: 'Photos unavailable',
                            reason: 'Enable access in system settings.',
                            state: AfriPermissionState.denied,
                            onContinue: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSessionTimeoutPrompt(
                            state: AfriSessionTimeoutState.offline,
                            onReauthenticate: _noop,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-async-state-catalog')),
        matchesGoldenFile(
          'goldens/universal_async_state_catalog_900x1600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal input state catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1400, 1600));
      final controllers = <TextEditingController>[];
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
      const inputKinds = <String>[
        'text',
        'number',
        'money',
        'phone',
        'email',
        'password',
        'date',
        'time',
        'multiline',
        'otp',
      ];
      const inputStates = <String>['default', 'disabled', 'error', 'empty'];

      Widget specimen(String kind, String state) {
        final controller = TextEditingController(
          text: state == 'empty' ? '' : _inputValue(kind),
        );
        controllers.add(controller);
        return _buildInputSpecimen(
          kind: kind,
          state: state,
          controller: controller,
        );
      }

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-input-state-catalog'),
            child: _CatalogPage(
              title: 'Input default, disabled, error, and empty states',
              children: [
                Row(
                  children: [
                    const SizedBox(width: 112),
                    for (final state in inputStates)
                      Expanded(
                        child: Text(
                          state,
                          textAlign: TextAlign.center,
                          style: TypographyTokens.labelMedium(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                for (final kind in inputKinds) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 112,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: SpacingTokens.spacing4,
                          ),
                          child: Text(
                            kind,
                            style: TypographyTokens.labelMedium(),
                          ),
                        ),
                      ),
                      for (final state in inputStates)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: SpacingTokens.spacing2,
                            ),
                            child: specimen(kind, state),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                ],
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-input-state-catalog')),
        matchesGoldenFile(
          'goldens/universal_input_state_catalog_1400x1600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal media state catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1400, 1600));
      final imageBytes = Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
        ),
      );
      final image = MemoryImage(imageBytes);

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-media-state-catalog'),
            child: _CatalogPage(
              title: 'Media state contracts',
              children: [
                const _CatalogLabel('Governed image'),
                Wrap(
                  spacing: SpacingTokens.spacing3,
                  runSpacing: SpacingTokens.spacing3,
                  children: [
                    for (final state in AfriGovernedImageState.values)
                      _MediaSpecimenTile(
                        label: state.name,
                        width: 176,
                        child: AfriGovernedImage(
                          image: image,
                          width: 176,
                          height: 96,
                          semanticLabel: 'Synthetic supporter image',
                          provenanceId: 'catalog-${state.name}',
                          rightsApproved: true,
                          state: state,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                const _CatalogLabel('Video thumbnail'),
                Wrap(
                  spacing: SpacingTokens.spacing3,
                  runSpacing: SpacingTokens.spacing3,
                  children: [
                    for (final state in AfriGovernedImageState.values)
                      _MediaSpecimenTile(
                        label: state.name,
                        width: 176,
                        child: AfriVideoThumbnail(
                          image: image,
                          width: 176,
                          height: 96,
                          semanticLabel: 'Synthetic match highlights',
                          provenanceId: 'catalog-video-${state.name}',
                          rightsApproved: true,
                          state: state,
                          onPlay: _noop,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                const _CatalogLabel('Document preview'),
                Wrap(
                  spacing: SpacingTokens.spacing3,
                  runSpacing: SpacingTokens.spacing3,
                  children: [
                    for (final state in AfriDocumentState.values)
                      SizedBox(
                        width: 420,
                        child: _MediaSpecimenTile(
                          label: state.name,
                          child: AfriDocumentPreview(
                            title: 'Membership terms',
                            fileType: 'PDF',
                            provenanceLabel: 'official club document',
                            state: state,
                            onOpen: _noop,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing5),
                const _CatalogLabel('QR and barcode surface'),
                Wrap(
                  spacing: SpacingTokens.spacing3,
                  runSpacing: SpacingTokens.spacing3,
                  children: [
                    for (final state in AfriQrBarcodeState.values)
                      SizedBox(
                        width: 310,
                        child: _MediaSpecimenTile(
                          label: state.name,
                          child: AfriQrBarcodeSurface(
                            code: ColoredBox(
                              color: ColorTokens.onSurface,
                              child: Center(
                                child: Icon(
                                  AfriIcons.qrCode,
                                  size: 120,
                                  color: ColorTokens.background,
                                ),
                              ),
                            ),
                            semanticLabel: 'Synthetic ticket code',
                            state: state,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-media-state-catalog')),
        matchesGoldenFile(
          'goldens/universal_media_state_catalog_1400x1600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal security state catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1400, 2200));

      await tester.pumpWidget(
        _catalogApp(
          const RepaintBoundary(
            key: ValueKey('universal-security-state-catalog'),
            child: _CatalogPage(
              title: 'Security, permission, and consent states',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Masked and reveal controls'),
                          AfriSurfaceCard(
                            child: AfriMaskedValue(
                              label: 'Member number',
                              value: 'RSFC-240071',
                              visibleCharacterCount: 2,
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSurfaceCard(
                            child: AfriMaskedValue(
                              label: 'Member number',
                              value: 'RSFC-240071',
                              visibleByDefault: true,
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSurfaceCard(
                            child: AfriMaskedValue(
                              label: 'Member number',
                              value: 'RSFC-240071',
                              visibleCharacterCount: 2,
                              enabled: false,
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          _CatalogLabel('Session timeout'),
                          AfriSessionTimeoutPrompt(
                            state: AfriSessionTimeoutState.warning,
                            remaining: Duration(minutes: 2),
                            onReauthenticate: _noop,
                            onDismiss: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriSessionTimeoutPrompt(
                            state: AfriSessionTimeoutState.expired,
                            onReauthenticate: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          _CatalogLabel('Permission recovery'),
                          AfriPermissionPrompt(
                            title: 'Photos permission',
                            reason: 'Choose one image only when you continue.',
                            state: AfriPermissionState.education,
                            onContinue: _noop,
                            onDecline: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriPermissionPrompt(
                            title: 'Photos permission denied',
                            reason: 'Review access before opening settings.',
                            state: AfriPermissionState.permanentlyDenied,
                            onContinue: _noop,
                            onOpenSettings: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriPermissionPrompt(
                            title: 'Photos unavailable',
                            reason: 'This device cannot provide photo access.',
                            state: AfriPermissionState.unavailable,
                            onContinue: _noop,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: SpacingTokens.spacing5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Consent review'),
                          AfriConsentReview(
                            title: 'Success-ready choices',
                            items: [
                              AfriConsentItem(
                                id: 'terms',
                                title: 'Terms',
                                description: 'Required to continue',
                                accepted: true,
                                required: true,
                              ),
                            ],
                            onChanged: _consentNoop,
                            onConfirm: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriConsentReview(
                            title: 'Required choice missing',
                            items: [
                              AfriConsentItem(
                                id: 'terms',
                                title: 'Terms',
                                description: 'Required to continue',
                                accepted: false,
                                required: true,
                              ),
                            ],
                            onChanged: _consentNoop,
                            onConfirm: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriConsentReview(
                            title: 'Consent validation error',
                            items: [
                              AfriConsentItem(
                                id: 'terms',
                                title: 'Terms',
                                description: 'Required to continue',
                                accepted: false,
                                required: true,
                              ),
                            ],
                            errorText: 'Review the required choice',
                            onChanged: _consentNoop,
                            onConfirm: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriConsentReview(
                            title: 'No consent choices',
                            items: [],
                            onChanged: _consentNoop,
                            onConfirm: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing3),
                          AfriConsentReview(
                            title: 'Confirmation unavailable',
                            items: [
                              AfriConsentItem(
                                id: 'analytics',
                                title: 'Product analytics',
                                description: 'Optional and off by default',
                                accepted: false,
                              ),
                            ],
                            onChanged: _consentNoop,
                            onConfirm: null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-security-state-catalog')),
        matchesGoldenFile(
          'goldens/universal_security_state_catalog_1400x2200'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal button state catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1000, 1200));
      const buttonKinds = <String>[
        'primary',
        'secondary',
        'tertiary',
        'destructive',
        'icon_only',
        'split',
      ];
      const buttonStates = <String>['default', 'loading', 'disabled'];

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-button-state-catalog'),
            child: _CatalogPage(
              title: 'Button default, loading, and disabled states',
              children: [
                Row(
                  children: [
                    const SizedBox(width: 132),
                    for (final state in buttonStates)
                      Expanded(
                        child: Text(
                          state,
                          textAlign: TextAlign.center,
                          style: TypographyTokens.labelMedium(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                for (final kind in buttonKinds) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 132,
                        child: Text(
                          kind,
                          style: TypographyTokens.labelMedium(),
                        ),
                      ),
                      for (final state in buttonStates)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: SpacingTokens.spacing3,
                            ),
                            child: Center(
                              child: _buildButtonSpecimen(
                                kind: kind,
                                state: state,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                ],
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-button-state-catalog')),
        matchesGoldenFile(
          'goldens/universal_button_state_catalog_1000x1200'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal shell overlay and menu catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1400, 2400));
      final searchControllers = <TextEditingController>[
        TextEditingController(text: 'supporters'),
        TextEditingController(),
        TextEditingController(text: 'locked query'),
        TextEditingController(text: 'invalid query'),
      ];
      addTearDown(() {
        for (final controller in searchControllers) {
          controller.dispose();
        }
      });

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-shell-overlay-menu-catalog'),
            child: _CatalogPage(
              title: 'Shell, overlay, search, and command states',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _CatalogLabel('Search states'),
                          AfriSearchInputField(
                            controller: searchControllers[0],
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriSearchInputField(
                            controller: searchControllers[1],
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriSearchInputField(
                            controller: searchControllers[2],
                            enabled: false,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriSearchInputField(
                            controller: searchControllers[3],
                            errorText: 'Search could not be completed',
                          ),
                          const SizedBox(height: SpacingTokens.spacing5),
                          const _CatalogLabel('Inline validation'),
                          const AfriInlineValidation(
                            message: 'Enter a specific query',
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriInlineValidation(
                            message: 'Query is valid',
                            tone: AfriInlineValidationTone.success,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriInlineValidation(
                            message: 'Review the selected scope',
                            tone: AfriInlineValidationTone.warning,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          const AfriInlineValidation(
                            message: 'A query is required',
                            tone: AfriInlineValidationTone.error,
                          ),
                          const SizedBox(height: SpacingTokens.spacing5),
                          const _CatalogLabel('Media and stable icons'),
                          const Row(
                            children: [
                              AfriAvatar(
                                semanticLabel: 'Aline Mukamana',
                                initials: 'Aline Mukamana',
                                size: 64,
                              ),
                              SizedBox(width: SpacingTokens.spacing4),
                              Icon(AfriIcons.home),
                              SizedBox(width: SpacingTokens.spacing3),
                              Icon(AfriIcons.wallet),
                              SizedBox(width: SpacingTokens.spacing3),
                              Icon(AfriIcons.statusWarning),
                              SizedBox(width: SpacingTokens.spacing3),
                              Icon(AfriIcons.statusError),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing5),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Adaptive shell'),
                          AfriTopCommandBar(
                            searchHint: 'Search fans and fixtures',
                            onSearchTap: _noop,
                            onAvatarTap: _noop,
                            showNotificationDot: true,
                            actions: [
                              AfriTopCommandAction(
                                icon: AfriIcons.settings,
                                label: 'Settings',
                                onTap: _noop,
                              ),
                            ],
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          AfriBreadcrumbs(
                            items: [
                              AfriBreadcrumbItem(label: 'Home', onTap: _noop),
                              AfriBreadcrumbItem(label: 'Current route'),
                            ],
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          SizedBox(
                            height: 250,
                            child: AfriScreenScaffold(
                              showAppBar: false,
                              scrollable: false,
                              constrainContent: false,
                              title: 'Keyboard-safe route',
                              child: Text('Safe-area and resize-aware content'),
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          DefaultTabController(
                            length: 3,
                            child: AfriTabBar.segmented(
                              disabledIndices: {2},
                              tabs: [
                                Tab(text: 'Live'),
                                Tab(text: 'Upcoming'),
                                Tab(text: 'Locked'),
                              ],
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          SizedBox(
                            height: 310,
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
                                  label: 'Wallet unavailable',
                                  icon: AfriIcons.wallet,
                                  selectedIcon: AfriIcons.wallet,
                                  enabled: false,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              AfriPopover(
                                tooltip: 'More details',
                                contentBuilder: _popoverContent,
                              ),
                              AfriPopupMenuButton<String>(
                                tooltip: 'Default menu',
                                onSelected: _stringNoop,
                                itemBuilder: _catalogMenuItems,
                                child: Icon(AfriIcons.more),
                              ),
                              AfriPopupMenuButton<String>(
                                tooltip: 'Disabled menu',
                                enabled: false,
                                onSelected: _stringNoop,
                                itemBuilder: _catalogMenuItems,
                                child: Icon(AfriIcons.more),
                              ),
                            ],
                          ),
                          SizedBox(height: SpacingTokens.spacing5),
                          AfriDocumentPreview(
                            title: 'Unavailable document',
                            fileType: 'PDF',
                            provenanceLabel: 'official club document',
                            enabled: false,
                            onOpen: _noop,
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          AfriClubBottomNav(
                            currentIndex: 0,
                            onTap: _intNoop,
                            items: [
                              AfriClubNavItem(
                                icon: AfriIcons.home,
                                label: 'Home',
                              ),
                              AfriClubNavItem(
                                icon: AfriIcons.wallet,
                                label: 'Wallet',
                              ),
                              AfriClubNavItem(
                                icon: AfriIcons.settings,
                                label: 'Settings',
                                enabled: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing5),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CatalogLabel('Overlay surfaces'),
                          SizedBox(
                            height: 260,
                            child: AfriAlertDialog(
                              title: Text('Confirm update'),
                              content: Text(
                                'Review the change before continuing.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: null,
                                  child: Text('Unavailable'),
                                ),
                                TextButton(
                                  onPressed: _noop,
                                  child: Text('Continue'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          AfriBottomSheet(
                            child: Text(
                              'Sheet content remains inside the safe area.',
                            ),
                          ),
                          SizedBox(height: SpacingTokens.spacing4),
                          AfriActionSheet(
                            title: 'Record actions',
                            actions: [
                              AfriSheetAction(
                                icon: AfriIcons.check,
                                label: 'Approve record',
                                onTap: _noop,
                              ),
                              AfriSheetAction(
                                icon: AfriIcons.delete,
                                label: 'Unavailable action',
                                onTap: _noop,
                                enabled: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing6),
                const _CatalogLabel('Command-menu states'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final state in AfriCommandMenuState.values) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              state.name,
                              style: TypographyTokens.labelMedium(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            AfriCommandMenuPanel<String>(
                              state: state,
                              selectedValue: 'profile',
                              onSelected: _stringNoop,
                              items: const [
                                AfriCommandItem(
                                  value: 'profile',
                                  label: 'Open member profile',
                                  icon: AfriIcons.profile,
                                ),
                                AfriCommandItem(
                                  value: 'locked',
                                  label: 'Unavailable command',
                                  icon: AfriIcons.lock,
                                  enabled: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing4),
                    ],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('empty'),
                          SizedBox(height: SpacingTokens.spacing2),
                          AfriCommandMenuPanel<String>(
                            items: [],
                            onSelected: _stringNoop,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-shell-overlay-menu-catalog')),
        matchesGoldenFile(
          'goldens/universal_shell_overlay_menu_catalog_1400x2400'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal transient feedback catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1400, 900));
      final cases = <_TransientFeedbackCase>[
        _TransientFeedbackCase(
          label: 'Snackbar information',
          show: (context) => AfriSnackbar.show(
            context,
            message: 'Information is available',
            duration: const Duration(days: 1),
          ),
        ),
        _TransientFeedbackCase(
          label: 'Snackbar success',
          show: (context) => AfriSnackbar.show(
            context,
            message: 'Changes were saved',
            tone: AfriSnackbarTone.success,
            duration: const Duration(days: 1),
          ),
        ),
        _TransientFeedbackCase(
          label: 'Snackbar warning',
          show: (context) => AfriSnackbar.show(
            context,
            message: 'Review is required',
            tone: AfriSnackbarTone.warning,
            duration: const Duration(days: 1),
          ),
        ),
        _TransientFeedbackCase(
          label: 'Snackbar error',
          show: (context) => AfriSnackbar.show(
            context,
            message: 'The action failed',
            tone: AfriSnackbarTone.error,
            duration: const Duration(days: 1),
          ),
        ),
        _TransientFeedbackCase(
          label: 'Toast information',
          show: (context) => AfriToast.info(context, 'Profile information'),
        ),
        _TransientFeedbackCase(
          label: 'Toast success',
          show: (context) => AfriToast.success(context, 'Profile updated'),
        ),
        _TransientFeedbackCase(
          label: 'Toast warning',
          show: (context) => AfriToast.warning(context, 'Review your profile'),
        ),
        _TransientFeedbackCase(
          label: 'Toast error',
          show: (context) => AfriToast.error(context, 'Profile update failed'),
        ),
      ];

      await tester.pumpWidget(
        _catalogApp(
          RepaintBoundary(
            key: const ValueKey('universal-transient-feedback-catalog'),
            child: _CatalogPage(
              title: 'Snackbar and toast states',
              children: [
                Wrap(
                  spacing: SpacingTokens.spacing4,
                  runSpacing: SpacingTokens.spacing4,
                  children: [
                    for (final feedbackCase in cases)
                      SizedBox(
                        width: 326,
                        height: 340,
                        child: _TransientFeedbackHost(
                          feedbackCase: feedbackCase,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byKey(const ValueKey('universal-transient-feedback-catalog')),
        matchesGoldenFile(
          'goldens/universal_transient_feedback_catalog_1400x900'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal open selection menu $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(800, 600));

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('universal-open-selection-menu'),
          child: _catalogApp(
            const Center(
              child: AfriPopupMenuButton<String>(
                tooltip: 'State menu',
                onSelected: _stringNoop,
                itemBuilder: _catalogMenuItems,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open state menu'),
                    SizedBox(width: SpacingTokens.spacing2),
                    Icon(AfriIcons.more),
                  ],
                ),
              ),
            ),
            brightness: brightness,
          ),
        ),
      );
      await tester.tap(find.byTooltip('State menu'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('universal-open-selection-menu')),
        matchesGoldenFile(
          'goldens/universal_open_selection_menu_800x600'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });

    testWidgets('golden universal deep-link recovery catalog $themeName', (
      tester,
    ) async {
      ColorTokens.setBrightness(brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setSurface(tester, const Size(1000, 700));

      await tester.pumpWidget(
        _catalogApp(
          const RepaintBoundary(
            key: ValueKey('universal-deep-link-recovery-catalog'),
            child: _CatalogPage(
              title: 'Deep-link recovery states',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AfriDeepLinkRecovery(
                        state: AfriDeepLinkRecoveryState.unavailable,
                        onAction: _noop,
                      ),
                    ),
                    SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: AfriDeepLinkRecovery(
                        state: AfriDeepLinkRecoveryState.error,
                        onAction: _noop,
                      ),
                    ),
                    SizedBox(width: SpacingTokens.spacing4),
                    Expanded(
                      child: AfriDeepLinkRecovery(
                        state: AfriDeepLinkRecoveryState.offline,
                        onAction: _noop,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('universal-deep-link-recovery-catalog')),
        matchesGoldenFile(
          'goldens/universal_deep_link_recovery_catalog_1000x700'
          '${brightness == Brightness.light ? '_light' : ''}.png',
        ),
      );
    });
  }
}

Widget _buildButtonSpecimen({required String kind, required String state}) {
  final loading = state == 'loading';
  final enabled = state != 'disabled';
  return switch (kind) {
    'icon_only' => AfriIconButton(
      icon: AfriIcons.settings,
      tooltip: 'Settings',
      isLoading: loading,
      onTap: enabled ? _noop : null,
    ),
    'split' => AfriSplitButton<String>(
      label: loading ? 'Saving' : 'Save',
      enabled: enabled,
      isLoading: loading,
      onPressed: _noop,
      itemBuilder: _buttonMenuItems,
      onSelected: _stringNoop,
    ),
    _ => AfriButton(
      label: loading ? 'Working' : _buttonLabel(kind),
      variant: switch (kind) {
        'secondary' => AfriButtonVariant.secondary,
        'tertiary' => AfriButtonVariant.ghost,
        'destructive' => AfriButtonVariant.destructive,
        _ => AfriButtonVariant.primary,
      },
      isLoading: loading,
      enabled: enabled,
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

List<PopupMenuEntry<String>> _buttonMenuItems(BuildContext context) => const [
  PopupMenuItem(value: 'draft', child: Text('Save as draft')),
];

List<PopupMenuEntry<String>> _catalogMenuItems(BuildContext context) => const [
  CheckedPopupMenuItem(
    value: 'selected',
    checked: true,
    child: Text('Selected item'),
  ),
  PopupMenuItem(
    value: 'disabled',
    enabled: false,
    child: Text('Disabled item'),
  ),
];

Widget _popoverContent(BuildContext context) => const Text('Anchored details');

String _inputValue(String kind) => switch (kind) {
  'number' => '24',
  'money' => '5000',
  'phone' => '+250788000111',
  'email' => 'fan@example.invalid',
  'password' => 'protected',
  'date' => '24 Jul 2026',
  'time' => '18:30',
  'multiline' => 'Short supporter note',
  'otp' => '123456',
  _ => 'Supporter value',
};

Widget _buildInputSpecimen({
  required String kind,
  required String state,
  required TextEditingController controller,
}) {
  final enabled = state != 'disabled';
  final errorText = state == 'error' ? 'Review this value' : null;
  return switch (kind) {
    'number' => AfriNumberInputField(
      controller: controller,
      label: 'Number',
      enabled: enabled,
      errorText: errorText,
    ),
    'money' => AfriMoneyInputField(
      controller: controller,
      currencySymbol: 'RWF',
      enabled: enabled,
      errorText: errorText,
    ),
    'phone' => AfriPhoneInputField(
      controller: controller,
      enabled: enabled,
      errorText: errorText,
    ),
    'email' => AfriEmailInputField(
      controller: controller,
      enabled: enabled,
      errorText: errorText,
    ),
    'password' => AfriPasswordInputField(
      controller: controller,
      enabled: enabled,
      errorText: errorText,
    ),
    'date' => AfriDateInputField(
      controller: controller,
      enabled: enabled,
      errorText: errorText,
      onSelected: _dateNoop,
    ),
    'time' => AfriTimeInputField(
      controller: controller,
      enabled: enabled,
      errorText: errorText,
      onSelected: _timeNoop,
    ),
    'multiline' => AfriInputField(
      controller: controller,
      label: 'Message',
      maxLines: 2,
      enabled: enabled,
      errorText: errorText,
    ),
    'otp' => AfriOtpInputField(
      controller: controller,
      enabled: enabled,
      errorText: errorText,
    ),
    _ => AfriInputField(
      controller: controller,
      label: 'Text',
      enabled: enabled,
      errorText: errorText,
    ),
  };
}

Widget _catalogApp(Widget child, {required Brightness brightness}) {
  const config = _CatalogConfig();
  return ClubConfigScope(
    config: config,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ClubTheme.from(config, brightness: brightness),
      home: Scaffold(body: child),
    ),
  );
}

class _CatalogPage extends StatelessWidget {
  const _CatalogPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ColorTokens.background,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: TypographyTokens.headlineMedium()),
            const SizedBox(height: SpacingTokens.spacing5),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CatalogLabel extends StatelessWidget {
  const _CatalogLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: Text(label, style: TypographyTokens.titleMedium()),
    );
  }
}

class _TransientFeedbackCase {
  const _TransientFeedbackCase({required this.label, required this.show});

  final String label;
  final void Function(BuildContext context) show;
}

class _TransientFeedbackHost extends StatefulWidget {
  const _TransientFeedbackHost({required this.feedbackCase});

  final _TransientFeedbackCase feedbackCase;

  @override
  State<_TransientFeedbackHost> createState() => _TransientFeedbackHostState();
}

class _TransientFeedbackHostState extends State<_TransientFeedbackHost> {
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.feedbackCase.label, style: TypographyTokens.labelMedium()),
        const SizedBox(height: SpacingTokens.spacing2),
        Expanded(
          child: ClipRRect(
            borderRadius: ShapeTokens.cardRadius,
            child: ScaffoldMessenger(
              child: Builder(
                builder: (context) {
                  if (!_scheduled) {
                    _scheduled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.feedbackCase.show(context);
                    });
                  }
                  return const Scaffold(body: SizedBox.expand());
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaSpecimenTile extends StatelessWidget {
  const _MediaSpecimenTile({
    required this.label,
    required this.child,
    this.width,
  });

  final String label;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing1),
          child,
        ],
      ),
    );
  }
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
void _timeNoop(TimeOfDay _) {}

class _CatalogConfig implements ClubConfig {
  const _CatalogConfig();

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
