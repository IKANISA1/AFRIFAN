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
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth:
                AfriComponentSizes.codeCellWidth * 6 +
                SpacingTokens.spacing2 * 4 +
                SpacingTokens.spacing6,
          ),
          child: Stack(
            children: [
              ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: Listenable.merge([controller, focusNode]),
                  builder: (context, _) => Row(
                    children: [
                      for (var index = 0; index < 6; index++) ...[
                        if (index > 0)
                          if (index == 3)
                            SizedBox(
                              width: SpacingTokens.spacing6,
                              child: Center(
                                child: Text(
                                  '−',
                                  style: TypographyTokens.bodyLarge(
                                    colors.secondaryText,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: SpacingTokens.spacing2),
                        Expanded(
                          child: Container(
                            height: MediaQuery.textScalerOf(context)
                                .scale(SpacingTokens.spacing6)
                                .clamp(
                                  AfriComponentSizes.codeCellHeight,
                                  double.infinity,
                                ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  focusNode.hasFocus &&
                                      controller.text.length.clamp(0, 5) ==
                                          index
                                  ? Color.alphaBlend(
                                      colors.primaryText.withValues(
                                        alpha: 0.10,
                                      ),
                                      colors.inputSurface,
                                    )
                                  : colors.inputSurface,
                              borderRadius: ShapeTokens.codeCellRadius,
                              border: errorText != null
                                  ? BorderTokens.all(color: colors.danger)
                                  : null,
                            ),
                            child: index < controller.text.length
                                ? Text(
                                    '•',
                                    style: TypographyTokens.headlineMedium(),
                                  )
                                : focusNode.hasFocus &&
                                      controller.text.length == index
                                ? Container(
                                    width: BorderTokens.emphasis,
                                    height: SpacingTokens.spacing6,
                                    color: colors.primaryText,
                                  )
                                : null,
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
