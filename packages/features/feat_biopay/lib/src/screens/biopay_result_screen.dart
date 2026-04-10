import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/biopay_task_result.dart';
import '../widgets/biopay_reference_ui.dart';

class BiopayResultScreen extends StatelessWidget {
  const BiopayResultScreen({required this.args, super.key});

  final BiopayTaskResultArgs args;

  @override
  Widget build(BuildContext context) {
    final isSuccess = args.tone == BiopayTaskResultTone.success;
    final accent = switch (args.tone) {
      BiopayTaskResultTone.success => biopayReferenceGreen,
      BiopayTaskResultTone.error => Colors.red.shade500,
      BiopayTaskResultTone.blocked => Colors.orange.shade500,
      BiopayTaskResultTone.pending => biopayReferenceBlue,
    };
    final panelColor = switch (args.tone) {
      BiopayTaskResultTone.success => const Color(0xFFD7F8DE),
      BiopayTaskResultTone.error => const Color(0xFFFBE3E3),
      BiopayTaskResultTone.blocked => const Color(0xFFFFF0D8),
      BiopayTaskResultTone.pending => const Color(0xFFDCE7FF),
    };
    final icon = switch (args.tone) {
      BiopayTaskResultTone.success => Icons.check_rounded,
      BiopayTaskResultTone.error => Icons.close_rounded,
      BiopayTaskResultTone.blocked => Icons.warning_rounded,
      BiopayTaskResultTone.pending => Icons.schedule_rounded,
    };

    return Scaffold(
      backgroundColor: biopayReferenceBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BiopayReferenceLightBackButton(
                    onTap: () => context.go(args.primaryRoute),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: panelColor,
                      ),
                      child: Icon(icon, color: accent, size: 70),
                    ),
                    const SizedBox(height: 34),
                    if (isSuccess)
                      Text(
                        'ENROLLMENT SUCCESS',
                        style: biopayReferenceText(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: biopayReferenceMuted,
                          letterSpacing: 2.2,
                        ),
                      ),
                    if (isSuccess) const SizedBox(height: 14),
                    Text(
                      args.title,
                      style: biopayReferenceText(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (args.message.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        args.message,
                        style: biopayReferenceText(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF667A9E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 42),
                    BiopayReferencePrimaryButton(
                      label: args.primaryLabel,
                      onTap: () => context.go(args.primaryRoute),
                    ),
                    if (args.secondaryLabel != null &&
                        args.secondaryRoute != null) ...[
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () => context.go(args.secondaryRoute!),
                        child: Text(
                          args.secondaryLabel!,
                          style: biopayReferenceText(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: biopayReferenceMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
