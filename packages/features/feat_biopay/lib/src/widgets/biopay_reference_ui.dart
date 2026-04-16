import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../biopay_tokens.dart';

// ── Legacy  → BioPayTokens ──
// Kept as getters so existing call sites continue to compile.
// TODO(#AFRI-106): Migrate callers to BioPayTokens directly, then remove these aliases.
Color get BioPayReferenceBackground => BioPayTokens.background;
Color get BioPayReferencePanel => BioPayTokens.panel;
Color get BioPayReferenceInk => BioPayTokens.ink;
Color get BioPayReferenceMuted => BioPayTokens.muted;
Color get BioPayReferenceBlue => BioPayTokens.accent;
Color get BioPayReferencePurple => BioPayTokens.featurePurple;
Color get BioPayReferenceOrange => BioPayTokens.featureOrange;
Color get BioPayReferenceTeal => BioPayTokens.featureTeal;
Color get BioPayReferenceGreen => BioPayTokens.successAccent;

TextStyle BioPayReferenceText({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TypographyTokens.editorialFont(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? BioPayReferenceInk,
    height: height,
    letterSpacing: letterSpacing,
  );
}

BoxDecoration BioPayReferencePanelDecoration({
  Color? color,
  double radius = 30,
}) {
  return BoxDecoration(
    color: color ?? BioPayReferencePanel,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: ColorTokens.ambientShadow.withValues(alpha: 0.26),
        blurRadius: 24,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

String BioPayReferenceFormatNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class BioPayReferencePage extends StatelessWidget {
  const BioPayReferencePage({
    required this.child,
    this.title,
    this.onBack,
    this.trailing,
    super.key,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioPayReferenceBackground,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: BioPayReferenceLightBackButton(onTap: onBack!),
                        ),
                      if (title != null)
                        Center(
                          child: Text(
                            title!,
                            style: BioPayReferenceText(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (trailing != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BioPayReferenceLightBackButton extends StatelessWidget {
  const BioPayReferenceLightBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BioPayReferencePanelDecoration(
          color: BioPayTokens.panelLight,
          radius: 18,
        ),
        child: Icon(
          AfriIcons.chevronLeft,
          size: 34,
          color: BioPayReferenceInk,
        ),
      ),
    );
  }
}

class BioPayReferenceDarkBackButton extends StatelessWidget {
  const BioPayReferenceDarkBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          AfriIcons.chevronLeft,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

class BioPayReferenceProfileButton extends StatelessWidget {
  const BioPayReferenceProfileButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: BioPayTokens.panelLight,
          shape: BoxShape.circle,
          border: BorderTokens.all(color: ColorTokens.onSurface, opacity: 0.06),
          boxShadow: [
            BoxShadow(
              color: ColorTokens.ambientShadow.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(
          AfriIcons.profile,
          color: BioPayTokens.iconMuted,
          size: 26,
        ),
      ),
    );
  }
}

class BioPayReferenceSegmentedControl extends StatelessWidget {
  const BioPayReferenceSegmentedControl({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final PaymentRecipientType selected;
  final ValueChanged<PaymentRecipientType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, PaymentRecipientType value) {
      final isSelected = selected == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? BioPayTokens.panelLight : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ColorTokens.ambientShadow.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: BioPayReferenceText(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? BioPayReferenceBlue : BioPayReferenceMuted,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 64,
      decoration: BioPayReferencePanelDecoration(radius: 24),
      child: Row(
        children: [
          tab('NUMBER', PaymentRecipientType.phoneNumber),
          tab('CODE', PaymentRecipientType.code),
        ],
      ),
    );
  }
}

class BioPayReferenceValueCard extends StatelessWidget {
  const BioPayReferenceValueCard({
    required this.label,
    this.value,
    this.controller,
    this.hintText,
    this.prefix,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final TextEditingController? controller;
  final String? hintText;
  final String? prefix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  bool get _editable => controller != null;

  @override
  Widget build(BuildContext context) {
    final content = _editable
        ? Row(
            children: [
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: BioPayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: BioPayReferenceMuted.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  onChanged: onChanged,
                  style: BioPayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: hintText,
                    hintStyle: BioPayReferenceText(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: BioPayReferenceMuted.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: BioPayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: BioPayReferenceMuted.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  value ?? '',
                  style: BioPayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: (value == null || value!.isEmpty)
                        ? BioPayReferenceMuted.withValues(alpha: 0.55)
                        : BioPayReferenceInk,
                  ),
                ),
              ),
            ],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
      decoration: BioPayReferencePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: BioPayReferenceText(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: BioPayReferenceMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }
}

class BioPayReferencePrimaryButton extends StatelessWidget {
  const BioPayReferencePrimaryButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.textColor = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final Color textColor;

  Color get _resolvedColor => color ?? BioPayTokens.accent;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: !isEnabled
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap!();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isEnabled ? 1 : 0.55,
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: _resolvedColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _resolvedColor.withValues(alpha: 0.24),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 28),
                const SizedBox(width: 14),
              ],
              Text(
                label,
                style: BioPayReferenceText(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BioPayReferenceHomeTile extends StatelessWidget {
  const BioPayReferenceHomeTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 124 || constraints.maxHeight < 132;
          final padding = compact ? 18.0 : 24.0;
          final iconSize = compact ? 40.0 : 48.0;
          final gap = compact ? 14.0 : 24.0;
          final labelHeight = compact ? 22.0 : 28.0;
          final fontSize = compact ? 17.0 : 20.0;

          return Container(
            decoration: BioPayReferencePanelDecoration(radius: 34),
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: iconSize),
                SizedBox(height: gap),
                SizedBox(
                  height: labelHeight,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: BioPayReferenceText(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BioPayReferenceStatusPill extends StatelessWidget {
  const BioPayReferenceStatusPill({
    required this.label,
    this.textColor = Colors.white,
    this.backgroundColor,
    super.key,
  });

  final String label;
  final Color textColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundColor ?? BioPayTokens.statusPillBackground,
        borderRadius: BorderRadius.circular(26),
        border: BorderTokens.all(color: Colors.white, opacity: 0.12),
      ),
      child: Text(
        label,
        style: BioPayReferenceText(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
