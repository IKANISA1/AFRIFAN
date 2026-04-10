import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const biopayReferenceBackground = Color(0xFFFFFFFF);
const biopayReferencePanel = Color(0xFFF4F7FB);
const biopayReferenceInk = Color(0xFF111A35);
const biopayReferenceMuted = Color(0xFF99A8C3);
const biopayReferenceBlue = Color(0xFF1352A6);
const biopayReferencePurple = Color(0xFF4B3BFF);
const biopayReferenceOrange = Color(0xFFFF9800);
const biopayReferenceTeal = Color(0xFF0D9B8A);
const biopayReferenceGreen = Color(0xFF1FC34A);

TextStyle biopayReferenceText({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w700,
  Color color = biopayReferenceInk,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

BoxDecoration biopayReferencePanelDecoration({
  Color color = biopayReferencePanel,
  double radius = 30,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

String biopayReferenceFormatNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class BiopayReferencePage extends StatelessWidget {
  const BiopayReferencePage({
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
      backgroundColor: biopayReferenceBackground,
      body: SafeArea(
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
                        child: BiopayReferenceLightBackButton(onTap: onBack!),
                      ),
                    if (title != null)
                      Center(
                        child: Text(
                          title!,
                          style: biopayReferenceText(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (trailing != null)
                      Align(alignment: Alignment.centerRight, child: trailing!),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class BiopayReferenceLightBackButton extends StatelessWidget {
  const BiopayReferenceLightBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.chevron_left_rounded,
          size: 34,
          color: biopayReferenceInk,
        ),
      ),
    );
  }
}

class BiopayReferenceDarkBackButton extends StatelessWidget {
  const BiopayReferenceDarkBackButton({required this.onTap, super.key});

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
          Icons.chevron_left_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

class BiopayReferenceProfileButton extends StatelessWidget {
  const BiopayReferenceProfileButton({required this.onTap, super.key});

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
          color: const Color(0xFFF5F8FC),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: Color(0xFF8495B5),
          size: 26,
        ),
      ),
    );
  }
}

class BiopayReferenceSegmentedControl extends StatelessWidget {
  const BiopayReferenceSegmentedControl({
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
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: biopayReferenceText(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? biopayReferenceBlue : biopayReferenceMuted,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 64,
      decoration: biopayReferencePanelDecoration(radius: 24),
      child: Row(
        children: [
          tab('NUMBER', PaymentRecipientType.phoneNumber),
          tab('CODE', PaymentRecipientType.code),
        ],
      ),
    );
  }
}

class BiopayReferenceValueCard extends StatelessWidget {
  const BiopayReferenceValueCard({
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
                  style: biopayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: biopayReferenceMuted.withValues(alpha: 0.7),
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
                  style: biopayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: hintText,
                    hintStyle: biopayReferenceText(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: biopayReferenceMuted.withValues(alpha: 0.55),
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
                  style: biopayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: biopayReferenceMuted.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  value ?? '',
                  style: biopayReferenceText(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: (value == null || value!.isEmpty)
                        ? biopayReferenceMuted.withValues(alpha: 0.55)
                        : biopayReferenceInk,
                  ),
                ),
              ),
            ],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
      decoration: biopayReferencePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: biopayReferenceText(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: biopayReferenceMuted,
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

class BiopayReferencePrimaryButton extends StatelessWidget {
  const BiopayReferencePrimaryButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.color = biopayReferenceBlue,
    this.textColor = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final Color textColor;

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
            color: color,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.24),
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
                style: biopayReferenceText(
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

class BiopayReferenceHomeTile extends StatelessWidget {
  const BiopayReferenceHomeTile({
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
      child: Container(
        decoration: biopayReferencePanelDecoration(radius: 34),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 24),
            Text(
              label,
              style: biopayReferenceText(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class BiopayReferenceStatusPill extends StatelessWidget {
  const BiopayReferenceStatusPill({
    required this.label,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0xCC1F1F22),
    super.key,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: biopayReferenceText(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
