import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final surface in <(String, Size)>[
    ('mobile', const Size(393, 852)),
    ('tablet', const Size(720, 1024)),
  ]) {
    testWidgets(
      '${surface.$1} modal focus follows task order and returns to its trigger',
      (tester) async {
        tester.view.physicalSize = surface.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: _FocusHarness()));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Open form');

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Accessible modal form'), findsOneWidget);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Modal input');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Cancel modal');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Submit modal');

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Accessible modal form'), findsNothing);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Open form');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _FocusHarness extends StatefulWidget {
  const _FocusHarness();

  @override
  State<_FocusHarness> createState() => _FocusHarnessState();
}

class _FocusHarnessState extends State<_FocusHarness> {
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'Open form');

  @override
  void dispose() {
    _triggerFocus.dispose();
    super.dispose();
  }

  Future<void> _openForm() async {
    await showAfriBottomSheet<void>(
      context: context,
      builder: (context) => const _ModalForm(),
    );
    if (mounted) {
      _triggerFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AfriButton(
          label: 'Open form',
          focusNode: _triggerFocus,
          onTap: _openForm,
        ),
      ),
    );
  }
}

class _ModalForm extends StatefulWidget {
  const _ModalForm();

  @override
  State<_ModalForm> createState() => _ModalFormState();
}

class _ModalFormState extends State<_ModalForm> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'Modal input');
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'Cancel modal');
  final FocusNode _submitFocus = FocusNode(debugLabel: 'Submit modal');

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _cancelFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Accessible modal form'),
          const SizedBox(height: SpacingTokens.spacing3),
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: AfriInputField(
              controller: _controller,
              focusNode: _inputFocus,
              autofocus: true,
              label: 'Reference',
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: AfriButton(
              label: 'Cancel',
              focusNode: _cancelFocus,
              variant: AfriButtonVariant.outline,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          FocusTraversalOrder(
            order: const NumericFocusOrder(3),
            child: AfriButton(
              label: 'Submit',
              focusNode: _submitFocus,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
