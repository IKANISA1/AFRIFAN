import 'dart:math' as math;

import 'package:core_theme/core_theme.dart';
import 'package:flutter/gestures.dart';
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
  static const List<String> _standZones = <String>[
    'VIP Gold',
    'East Stand',
    'Tribune Red',
    'Standing',
  ];

  String? _selectedSeat;

  void _selectStand(String zone) {
    setState(() {
      _selectedSeat = '$zone, Seat 1';
    });
  }

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
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text('SELECT SEAT', style: TypographyTokens.headlineLarge()),
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
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
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECTED SEAT',
                            style: TypographyTokens.labelSmall().copyWith(
                              color: ColorTokens.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _selectedSeat!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypographyTokens.titleMedium(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing4),
                    AfriButton(
                      label: 'Confirm',
                      fullWidth: false,
                      onTap: () => context.pop(_selectedSeat),
                    ),
                  ],
                ),
              ),
            )
          : null,
      scrollable: false,
      child: Column(
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
                      return _TappableSeatMap(
                        size: size,
                        selectedSeat: _selectedSeat,
                        onSeatTap: _onSeatTap,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          _buildAccessibleStandPicker(),
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
    );
  }

  Widget _buildAccessibleStandPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        0,
        SpacingTokens.spacing4,
        SpacingTokens.spacing4,
      ),
      color: ColorTokens.background,
      child: Wrap(
        spacing: SpacingTokens.spacing2,
        runSpacing: SpacingTokens.spacing2,
        alignment: WrapAlignment.center,
        children: [
          for (final zone in _standZones)
            AfriButton(
              label: zone,
              fullWidth: false,
              variant: _selectedSeat?.startsWith(zone) == true
                  ? AfriButtonVariant.primary
                  : AfriButtonVariant.outline,
              semanticsLabel: _selectedSeat?.startsWith(zone) == true
                  ? 'Selected $zone stand'
                  : 'Select $zone stand',
              onTap: () => _selectStand(zone),
            ),
        ],
      ),
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

class _TappableSeatMap extends StatefulWidget {
  const _TappableSeatMap({
    required this.size,
    required this.selectedSeat,
    required this.onSeatTap,
  });

  final Size size;
  final String? selectedSeat;
  final void Function(Offset localPosition, Size size) onSeatTap;

  @override
  State<_TappableSeatMap> createState() => _TappableSeatMapState();
}

class _TappableSeatMapState extends State<_TappableSeatMap> {
  Offset? _pointerDownPosition;

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerDownPosition = null;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final downPosition = _pointerDownPosition;
    _pointerDownPosition = null;
    if (downPosition == null) {
      return;
    }
    if ((event.localPosition - downPosition).distance > kTouchSlop) {
      return;
    }
    widget.onSeatTap(event.localPosition, widget.size);
  }

  void _handleSemanticTap() {
    widget.onSeatTap(
        Offset(widget.size.width * 0.75, widget.size.height / 2), widget.size);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.selectedSeat == null
          ? 'Interactive stadium seat map'
          : 'Interactive stadium seat map, selected ${widget.selectedSeat}',
      hint: 'Tap a stand to select a seat',
      onTap: _handleSemanticTap,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerCancel: _handlePointerCancel,
        onPointerUp: _handlePointerUp,
        child: CustomPaint(
          size: widget.size,
          painter: StadiumPainter(selectedSeat: widget.selectedSeat != null),
        ),
      ),
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
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(ShapeTokens.radiusFull / 100),
    );
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
        ..color = ExternalBrandColors.stadiumPitch
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
