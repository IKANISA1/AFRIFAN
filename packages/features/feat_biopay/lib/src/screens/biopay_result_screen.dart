import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../biopay_tokens.dart';
import '../models/biopay_task_result.dart';
import '../widgets/biopay_reference_ui.dart';

class BioPayResultScreen extends StatelessWidget {
  const BioPayResultScreen({required this.args, super.key});

  final BioPayTaskResultArgs args;

  @override
  Widget build(BuildContext context) {
    final isSuccess = args.tone == BioPayTaskResultTone.success;
    final accent = switch (args.tone) {
      BioPayTaskResultTone.success => BioPayReferenceGreen,
      BioPayTaskResultTone.error => Colors.red.shade500,
      BioPayTaskResultTone.blocked => Colors.orange.shade500,
      BioPayTaskResultTone.pending => BioPayReferenceBlue,
    };
    final panelColor = switch (args.tone) {
      BioPayTaskResultTone.success => BioPayTokens.successPanel,
      BioPayTaskResultTone.error => BioPayTokens.errorPanel,
      BioPayTaskResultTone.blocked => BioPayTokens.blockedPanel,
      BioPayTaskResultTone.pending => BioPayTokens.pendingPanel,
    };
    final icon = switch (args.tone) {
      BioPayTaskResultTone.success => AfriIcons.check,
      BioPayTaskResultTone.error => AfriIcons.close,
      BioPayTaskResultTone.blocked => AfriIcons.warning,
      BioPayTaskResultTone.pending => AfriIcons.statusPending,
    };

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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BioPayReferenceLightBackButton(
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
                          style: BioPayReferenceText(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: BioPayReferenceMuted,
                            letterSpacing: 2.2,
                          ),
                        ),
                      if (isSuccess) const SizedBox(height: 14),
                      Text(
                        args.title,
                        style: BioPayReferenceText(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (args.message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          args.message,
                          style: BioPayReferenceText(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: BioPayTokens.mutedDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 42),
                      BioPayReferencePrimaryButton(
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
                            style: BioPayReferenceText(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: BioPayReferenceMuted,
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
      ),
    );
  }
}
