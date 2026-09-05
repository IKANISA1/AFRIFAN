import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions.dart';
import '../tokens/border_tokens.dart';
import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Six visual cells over one native editable field: autofill, paste and focus
/// remain a single task. Historical onboarding frame 10 supplies the 3–3 pattern.
class AfriCodeInput extends StatelessWidget {
  const AfriCodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.helperText,
    required this.onSubmitted,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String helperText;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.afriSemanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TypographyTokens.bodyMedium(colors.secondaryText)),
        const SizedBox(height: SpacingTokens.spacing2),
        Stack(
          children: [
            ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([controller, focusNode]),
                builder: (context, _) => Row(
                  children: [
                    for (var index = 0; index < 6; index++) ...[
                      if (index > 0)
                        SizedBox(
                          width: index == 3
                              ? SpacingTokens.spacing4
                              : SpacingTokens.spacing2,
                        ),
                      Expanded(
                        child: Container(
                          height: AfriComponentSizes.listRowHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.inputSurface,
                            borderRadius: BorderRadius.circular(
                              ShapeTokens.radiusControl,
                            ),
                            border: errorText != null
                                ? BorderTokens.all(color: colors.danger)
                                : focusNode.hasFocus &&
                                      controller.text.length.clamp(0, 5) ==
                                          index
                                ? BorderTokens.all(
                                    color: colors.primaryText,
                                    width: BorderTokens.emphasis,
                                  )
                                : null,
                          ),
                          child: Text(
                            index < controller.text.length ? '•' : '',
                            style: TypographyTokens.headlineMedium(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Semantics(
                label: label,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: autofocus,
                  obscureText: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  enableSuggestions: false,
                  autocorrect: false,
                  style: TypographyTokens.bodyLarge(ColorTokens.transparent),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                  onSubmitted: onSubmitted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Semantics(
          container: true,
          liveRegion: errorText != null,
          label: errorText == null ? null : '$label. Error: $errorText',
          excludeSemantics: errorText != null,
          child: Text(
            errorText ?? helperText,
            style: TypographyTokens.bodySmall(
              errorText == null ? colors.secondaryText : colors.danger,
            ),
          ),
        ),
      ],
    );
  }
}
