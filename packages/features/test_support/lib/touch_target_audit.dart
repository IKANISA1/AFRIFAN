import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audits every enabled tap-capable control currently rendered in a widget
/// test and fails with a deterministic inventory of undersized targets.
///
/// Primary-route tests should use the 48 logical-pixel default. A dense
/// 44-pixel exception is allowed only when the caller supplies the exact
/// [Key] in [approvedDenseKeys], making the exception reviewable in source.
void expectTapTargetsMeetMinimum(
  WidgetTester tester, {
  double minimum = 48,
  double approvedDenseMinimum = 44,
  Set<Key> approvedDenseKeys = const <Key>{},
}) {
  const measurementTolerance = 0.01;
  final failures = <String>[];
  final auditedElements = <Element>{};

  final candidates = find.byWidgetPredicate(_isEnabledTapControl);
  for (final element in candidates.evaluate()) {
    if (!auditedElements.add(element)) {
      continue;
    }
    var hasTapControlAncestor = false;
    var isFrameworkTextSelectionHandle = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget.runtimeType.toString() == '_SelectionHandleOverlay') {
        isFrameworkTextSelectionHandle = true;
        return false;
      }
      if (_isEnabledTapControl(ancestor.widget)) {
        hasTapControlAncestor = true;
        return false;
      }
      return true;
    });
    if (hasTapControlAncestor || isFrameworkTextSelectionHandle) {
      continue;
    }

    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      continue;
    }

    final widget = element.widget;
    final key = widget.key;
    final allowedMinimum = key != null && approvedDenseKeys.contains(key)
        ? approvedDenseMinimum
        : minimum;
    final size = renderObject.size;
    if (size.width + measurementTolerance >= allowedMinimum &&
        size.height + measurementTolerance >= allowedMinimum) {
      continue;
    }

    final ancestorTypes = <String>[];
    element.visitAncestorElements((ancestor) {
      if (ancestorTypes.length >= 15) {
        return false;
      }
      ancestorTypes.add(ancestor.widget.runtimeType.toString());
      return true;
    });
    failures.add(
      '${widget.runtimeType}'
      '${key == null ? '' : ' key=$key'} '
      '${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)} '
      '(required ${allowedMinimum.toStringAsFixed(1)}x'
      '${allowedMinimum.toStringAsFixed(1)}; '
      'ancestors ${ancestorTypes.join(' > ')})',
    );
  }

  expect(
    candidates,
    findsWidgets,
    reason: 'The route audit must render at least one enabled tap target.',
  );
  expect(
    failures,
    isEmpty,
    reason: 'Undersized enabled tap targets:\n${failures.join('\n')}',
  );
}

bool _isEnabledTapControl(Widget widget) {
  return switch (widget) {
    AfriPressFeedback(:final onTap, :final enabled) => enabled && onTap != null,
    ButtonStyleButton(:final onPressed) => onPressed != null,
    IconButton(:final onPressed) => onPressed != null,
    FloatingActionButton(:final onPressed) => onPressed != null,
    TextField(:final enabled) => enabled != false,
    TextFormField(:final enabled) => enabled != false,
    InkWell(:final onTap, :final onLongPress, :final onDoubleTap) =>
      onTap != null || onLongPress != null || onDoubleTap != null,
    GestureDetector(:final onTap, :final onLongPress, :final onDoubleTap) =>
      onTap != null || onLongPress != null || onDoubleTap != null,
    ListTile(:final onTap, :final onLongPress, :final enabled) =>
      enabled && (onTap != null || onLongPress != null),
    Switch(:final onChanged) => onChanged != null,
    Checkbox(:final onChanged) => onChanged != null,
    final Radio<dynamic> radio => _radioIsEnabled(radio),
    ChoiceChip(:final onSelected) => onSelected != null,
    FilterChip(:final onSelected) => onSelected != null,
    ActionChip(:final onPressed) => onPressed != null,
    InputChip(:final onSelected, :final onPressed) =>
      onSelected != null || onPressed != null,
    PopupMenuButton<dynamic>(:final enabled) => enabled,
    DropdownButton<dynamic>(:final onChanged) => onChanged != null,
    _ => false,
  };
}

bool _radioIsEnabled(Radio<dynamic> radio) {
  // `onChanged` remains the compatibility signal until every supported Flutter
  // channel exposes route-owned RadioGroup state to widget inspection.
  // ignore: deprecated_member_use
  return radio.enabled ?? radio.onChanged != null;
}
