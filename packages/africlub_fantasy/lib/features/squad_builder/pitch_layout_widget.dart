import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/squad_builder/player_slot_widget.dart';
import 'package:africlub_fantasy/models/fantasy_player.dart';
import 'package:flutter/material.dart';

class PitchSlotData {
  const PitchSlotData({
    required this.label,
    required this.position,
    required this.onTap,
    this.player,
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.isBench = false,
    this.trailing,
  });

  final String label;
  final PlayerPosition position;
  final FantasyPlayer? player;
  final VoidCallback onTap;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isBench;
  final Widget? trailing;
}

class PitchLayoutWidget extends StatelessWidget {
  const PitchLayoutWidget({
    required this.rows,
    required this.bench,
    this.readOnly = false,
    super.key,
  });

  final List<List<PitchSlotData>> rows;
  final List<PitchSlotData> bench;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FantasyColors.pitchGreen,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: FantasyColors.pitchLineLight.withValues(alpha: 0.6),
        ),
      ),
      child: CustomPaint(
        painter: _PitchPainter(),
        child: Padding(
          padding: const EdgeInsets.all(FantasySpacing.md),
          child: Column(
            children: <Widget>[
              const SizedBox(height: FantasySpacing.sm),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: FantasySpacing.lg),
                  child: Row(
                    children: row
                        .map(
                          (slot) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: FantasySpacing.xs,
                              ),
                              child: PlayerSlotWidget(
                                label: slot.label,
                                onTap: slot.onTap,
                                playerName: slot.player?.shortName,
                                teamShort: slot.player?.teamShort,
                                priceLabel: slot.player == null
                                    ? null
                                    : '£${(slot.player!.price / 10).toStringAsFixed(1)}',
                                isCaptain: slot.isCaptain,
                                isViceCaptain: slot.isViceCaptain,
                                isBench: slot.isBench,
                                trailing: slot.trailing,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: 1,
                margin: const EdgeInsets.only(
                  top: FantasySpacing.sm,
                  bottom: FantasySpacing.md,
                ),
                color: FantasyColors.pitchLineLight.withValues(alpha: 0.55),
              ),
              Row(
                children: bench
                    .map(
                      (slot) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FantasySpacing.xs,
                          ),
                          child: PlayerSlotWidget(
                            label: slot.label,
                            onTap: slot.onTap,
                            playerName: slot.player?.shortName,
                            teamShort: slot.player?.teamShort,
                            priceLabel: slot.player == null
                                ? null
                                : '£${(slot.player!.price / 10).toStringAsFixed(1)}',
                            isCaptain: slot.isCaptain,
                            isViceCaptain: slot.isViceCaptain,
                            isBench: true,
                            trailing: slot.trailing,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = FantasyColors.pitchLineLight.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerY = size.height * 0.52;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
      linePaint,
    );
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);
    canvas.drawCircle(Offset(size.width / 2, centerY), 34, linePaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.25, 12, size.width * 0.5, 74),
      linePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.18, size.height - 86, size.width * 0.64, 74),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
