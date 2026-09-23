import 'package:flutter/material.dart';

import '../extensions.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_icon_button.dart';

/// Privacy-safe value display with an explicit reveal/hide control.
///
/// The hidden value is excluded from semantics and is never written to logs.
/// Callers remain responsible for authorization, timeout, and audit policy
/// before allowing a sensitive value to be revealed.
class AfriMaskedValue extends StatefulWidget {
  const AfriMaskedValue({
    required this.label,
    required this.value,
    this.visibleByDefault = false,
    this.maskCharacter = '•',
    this.visibleCharacterCount,
    this.onVisibilityChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String value;
  final bool visibleByDefault;
  final String maskCharacter;
  final int? visibleCharacterCount;
  final ValueChanged<bool>? onVisibilityChanged;
  final bool enabled;

  @override
  State<AfriMaskedValue> createState() => _AfriMaskedValueState();
}

class _AfriMaskedValueState extends State<AfriMaskedValue> {
  late bool _isVisible = widget.visibleByDefault;

  @override
  void didUpdateWidget(covariant AfriMaskedValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleByDefault != widget.visibleByDefault) {
      _isVisible = widget.visibleByDefault;
    }
  }

  void _toggleVisibility() {
    final next = !_isVisible;
    setState(() => _isVisible = next);
    widget.onVisibilityChanged?.call(next);
  }

  String get _maskedValue {
    final visibleCount = (widget.visibleCharacterCount ?? 0).clamp(
      0,
      widget.value.length,
    );
    final hiddenCount = widget.value.length - visibleCount;
    final hidden = List.filled(hiddenCount, widget.maskCharacter).join();
    if (visibleCount == 0) return hidden;
    return '$hidden${widget.value.substring(hiddenCount)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    final stateLabel = _isVisible ? 'visible' : 'hidden';
    final actionLabel = _isVisible
        ? 'Hide ${widget.label}'
        : 'Reveal ${widget.label}';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${widget.label}, $stateLabel',
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TypographyTokens.labelMedium(colors.secondaryText),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(
                    _isVisible ? widget.value : _maskedValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.bodyLarge(colors.primaryText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
          AfriIconButton(
            icon: _isVisible ? AfriIcons.visibilityOff : AfriIcons.visibility,
            tooltip: actionLabel,
            filled: false,
            onTap: widget.enabled ? _toggleVisibility : null,
          ),
        ],
      ),
    );
  }
}
