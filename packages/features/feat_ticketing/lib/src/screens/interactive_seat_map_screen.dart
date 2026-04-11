import 'dart:math' as math;
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InteractiveSeatMapScreen extends StatefulWidget {
  final String matchId;
  const InteractiveSeatMapScreen({super.key, required this.matchId});

  @override
  State<InteractiveSeatMapScreen> createState() =>
      _InteractiveSeatMapScreenState();
}

class _InteractiveSeatMapScreenState extends State<InteractiveSeatMapScreen> {
  String? _selectedSeat;

  void _onSeatTap(Offset localPosition, Size size) {
    // Simplified hit testing based on grid
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final dx = localPosition.dx - centerX;
    final dy = localPosition.dy - centerY;
    final distance = math.sqrt(dx * dx + dy * dy);

    // If tap is in the stands (between pitch and outer edge)
    if (distance > 60 && distance < 150) {
      // Determine angle to find zone
      final angle = math.atan2(dy, dx) * 180 / math.pi;

      String zone;
      if (angle > -45 && angle < 45) {
        zone = 'East Stand';
      } else if (angle > 45 && angle < 135) {
        zone = 'Tribune Red'; // Bottom
      } else if (angle > 135 || angle < -135) {
        zone = 'VIP Gold'; // West
      } else {
        zone = 'Standing'; // Top
      }

      setState(() {
        _selectedSeat = '$zone, Seat ${(angle.abs() * 10).toInt() % 100}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        title: Text('SELECT SEAT', style: TypographyTokens.headlineLarge()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onTapUp: (details) =>
                            _onSeatTap(details.localPosition, size),
                        child: CustomPaint(
                          size: size,
                          painter: StadiumPainter(
                            selectedSeat: _selectedSeat != null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Legend
          Container(
            padding: const EdgeInsets.all(SpacingTokens.spacing4),
            decoration: BoxDecoration(
              color: ColorTokens.surface,
              border: BorderTokens.top(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(ColorTokens.clubAccent, 'VIP'),
                _buildLegendItem(ColorTokens.clubPrimary, 'Tribune'),
                _buildLegendItem(ColorTokens.outlineVariant, 'Standing'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedSeat != null
          ? Container(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainerHighest,
                border: BorderTokens.top(),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SELECTED SEAT',
                            style: TypographyTokens.labelSmall()
                                .copyWith(color: ColorTokens.onSurfaceVariant)),
                        Text(_selectedSeat!,
                            style: TypographyTokens.titleMedium()),
                      ],
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ColorTokens.clubPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing8),
                        shape: RoundedRectangleBorder(
                            borderRadius: ShapeTokens.buttonRadius),
                      ),
                      onPressed: () {
                        context.pop(_selectedSeat);
                      },
                      child: Text('CONFIRM',
                          style: TypographyTokens.labelLarge()
                            ..copyWith(color: ColorTokens.onSurface)),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: SpacingTokens.spacing2),
        Text(label,
            style: TypographyTokens.labelSmall()
                .copyWith(color: ColorTokens.onSurfaceVariant)),
      ],
    );
  }
}

class StadiumPainter extends CustomPainter {
  final bool selectedSeat;

  StadiumPainter({required this.selectedSeat});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw Stadium Outer
    final outerRect = Rect.fromCenter(center: center, width: 280, height: 400);
    final outerRRect =
        RRect.fromRectAndRadius(outerRect, const Radius.circular(100));
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..color = ColorTokens.surfaceContainer
        ..style = PaintingStyle.fill,
    );

    // Draw Zones
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30;

    // West (VIP)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 240, height: 360),
      math.pi / 2 + 0.2, // startAngle
      math.pi - 0.4, // sweepAngle
      false,
      paint..color = ColorTokens.clubAccent,
    );

    // East (Standing)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 240, height: 360),
      -math.pi / 2 + 0.2,
      math.pi - 0.4,
      false,
      paint..color = ColorTokens.outlineVariant,
    );

    // North (Tribune Edge)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 240, height: 360),
      -math.pi / 2 - 0.2,
      0.4,
      false,
      paint..color = ColorTokens.clubPrimary,
    );

    // South (Tribune Red)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 240, height: 360),
      math.pi / 2 - 0.2,
      0.4,
      false,
      paint..color = ColorTokens.clubPrimary,
    );

    // Pitch
    final pitchRect = Rect.fromCenter(center: center, width: 100, height: 160);
    canvas.drawRect(
      pitchRect,
      Paint()
        // NOTE: Stadium pitch green — domain color, not club-specific
        ..color = const Color(0xFF1B5E20) // Deep dark green pitch
        ..style = PaintingStyle.fill,
    );

    // Pitch lines
    final linePaint = Paint()
      ..color = ColorTokens.onSurface.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(pitchRect, linePaint);
    canvas.drawLine(Offset(center.dx - 50, center.dy),
        Offset(center.dx + 50, center.dy), linePaint);
    canvas.drawCircle(center, 15, linePaint);
  }

  @override
  bool shouldRepaint(covariant StadiumPainter oldDelegate) =>
      oldDelegate.selectedSeat != selectedSeat;
}
