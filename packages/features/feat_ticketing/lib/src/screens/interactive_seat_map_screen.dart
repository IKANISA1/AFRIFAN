import 'dart:async';
import 'dart:math' as math;

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ticket_detail_provider.dart';

class InteractiveSeatMapScreen extends ConsumerStatefulWidget {
  final String matchId;
  const InteractiveSeatMapScreen({super.key, required this.matchId});

  @override
  ConsumerState<InteractiveSeatMapScreen> createState() =>
      _InteractiveSeatMapScreenState();
}

class _InteractiveSeatMapScreenState
    extends ConsumerState<InteractiveSeatMapScreen> {
  static const List<String> _standZones = <String>[
    'VIP Gold',
    'East Stand',
    'Tribune Red',
    'Standing',
  ];

  String? _selectedSeat;
  late bool _wasOnline;

  @override
  void initState() {
    super.initState();
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;
    if (!mounted) return;
    setState(() {});
    if (restored) {
      unawaited(
        ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
      );
    }
  }

  void _close([String? selectedSeat]) {
    if (context.canPop()) {
      context.pop(selectedSeat);
    } else {
      context.go('/tickets/detail/${widget.matchId}');
    }
  }

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
    final accessEnabled = ref.watch(seatMapAccessEnabledProvider);
    final detailAsync = ref.watch(ticketDetailProvider(widget.matchId));
    final mapAvailable =
        accessEnabled && detailAsync.valueOrNull?.match != null;
    final stackSelection = MediaQuery.textScalerOf(context).scale(16) >= 28;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text('SELECT SEAT', style: TypographyTokens.headlineLarge()),
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          key: const ValueKey<String>('seat-map-back'),
          icon: AfriIcons.back,
          onTap: _close,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
      ),
      bottomNavigationBar: mapAvailable && _selectedSeat != null
          ? Container(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              decoration: BoxDecoration(
                color: ColorTokens.surfaceContainerHighest,
                border: BorderTokens.top(),
              ),
              child: SafeArea(
                child: stackSelection
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SelectedSeatLabel(
                            selectedSeat: _selectedSeat!,
                            maxLines: 2,
                          ),
                          const SizedBox(height: SpacingTokens.spacing3),
                          AfriButton(
                            label: 'Confirm',
                            onTap: () => _close(_selectedSeat),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _SelectedSeatLabel(
                              selectedSeat: _selectedSeat!,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: SpacingTokens.spacing4),
                          AfriButton(
                            label: 'Confirm',
                            fullWidth: false,
                            onTap: () => _close(_selectedSeat),
                          ),
                        ],
                      ),
              ),
            )
          : null,
      scrollable: false,
      child: !accessEnabled
          ? _SeatMapConsequence(
              title: 'Seat selection unavailable',
              body: 'Seat selection is not enabled for this build or club.',
              actionLabel: 'BACK TO TICKET',
              onAction: _close,
            )
          : detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing4),
                child: AfriSkeletonList(),
              ),
              error: (error, _) => _failureConsequence(error),
              data: (detail) {
                if (detail.match == null) {
                  return _SeatMapConsequence(
                    title: 'Seat map unavailable',
                    body: 'This fixture could not be found.',
                    actionLabel: 'BACK TO TICKET',
                    onAction: _close,
                  );
                }
                return _buildMapContent(
                  detail,
                  compactControls: stackSelection,
                );
              },
            ),
    );
  }

  Widget _buildMapContent(
    TicketDetailState detail, {
    required bool compactControls,
  }) {
    return Column(
      children: [
        if (_retainedBanner(detail) case final banner?) banner,
        Expanded(
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
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
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
              _buildAccessibleStandPicker(compact: compactControls),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SpacingTokens.spacing4),
                decoration: BoxDecoration(
                  color: ColorTokens.surface,
                  border: BorderTokens.top(),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem(ColorTokens.clubAccent, 'VIP'),
                      const SizedBox(width: SpacingTokens.spacing4),
                      _buildLegendItem(ColorTokens.clubPrimary, 'Tribune'),
                      const SizedBox(width: SpacingTokens.spacing4),
                      _buildLegendItem(
                        ColorTokens.outlineVariant,
                        'Standing',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _failureConsequence(Object error) {
    final failure = error is TicketDetailFailure
        ? error
        : TicketDetailFailure.fromError(error);
    return switch (failure.kind) {
      TicketDetailFailureKind.offline => _SeatMapConsequence(
          title: 'Seat map unavailable offline',
          body: 'Connect to confirm current seat availability.',
          actionLabel: 'BACK TO TICKET',
          onAction: _close,
        ),
      TicketDetailFailureKind.permissionDenied => _SeatMapConsequence(
          title: 'Seat map access denied',
          body: 'This fixture is not available for the current club account.',
          actionLabel: 'BACK TO TICKET',
          onAction: _close,
        ),
      TicketDetailFailureKind.securityTimeout => _SeatMapConsequence(
          title: 'Seat map security check timed out',
          body: 'The fixture could not be confirmed safely. Try again.',
          actionLabel: 'TRY AGAIN',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        ),
      TicketDetailFailureKind.conflict => _SeatMapConsequence(
          title: 'Seat map changed',
          body: 'Refresh the fixture before selecting a seat.',
          actionLabel: 'REFRESH SEAT MAP',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        ),
      TicketDetailFailureKind.unknown => _SeatMapConsequence(
          title: 'Unable to load seat map',
          body: 'The fixture could not be confirmed. Try again.',
          actionLabel: 'TRY AGAIN',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).load(),
        ),
    };
  }

  Widget? _retainedBanner(TicketDetailState detail) {
    if (!ConnectivityService.isOnline) {
      return const _SeatMapStatus(
        title: 'Showing saved seat map',
        body:
            'Seat availability may have changed. Reconnect before confirming.',
      );
    }
    if (detail.phase == TicketDetailPhase.syncing) {
      return const _SeatMapStatus(
        title: 'Refreshing seat map',
        body: 'The last confirmed fixture remains visible.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = detail.failure;
    if (failure == null) return null;
    return switch (failure.kind) {
      TicketDetailFailureKind.conflict => _SeatMapStatus(
          title: 'Seat map changed',
          body:
              'These are the last confirmed stands. Refresh before selecting.',
          actionLabel: 'REFRESH SEAT MAP',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
        ),
      TicketDetailFailureKind.securityTimeout => _SeatMapStatus(
          title: 'Seat map check timed out',
          body:
              'These are the last confirmed stands. Refresh before selecting.',
          actionLabel: 'REFRESH SEAT MAP',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
        ),
      TicketDetailFailureKind.permissionDenied => const _SeatMapStatus(
          title: 'Seat access changed',
          body: 'The saved map is read-only. Return to the ticket to continue.',
          tone: AfriStateBannerTone.danger,
        ),
      TicketDetailFailureKind.offline => const _SeatMapStatus(
          title: 'Showing saved seat map',
          body:
              'Seat availability may have changed. Reconnect before confirming.',
        ),
      TicketDetailFailureKind.unknown => _SeatMapStatus(
          title: 'Seat map refresh failed',
          body:
              'These are the last confirmed stands. Refresh before selecting.',
          actionLabel: 'REFRESH SEAT MAP',
          onAction: () =>
              ref.read(ticketDetailProvider(widget.matchId).notifier).refresh(),
        ),
    };
  }

  Widget _buildAccessibleStandPicker({required bool compact}) {
    final buttons = <Widget>[
      for (final zone in _standZones)
        Semantics(
          selected: _selectedSeat?.startsWith(zone) == true,
          child: AfriButton(
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
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        0,
        SpacingTokens.spacing4,
        SpacingTokens.spacing4,
      ),
      color: ColorTokens.background,
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    if (index > 0)
                      const SizedBox(width: SpacingTokens.spacing2),
                    buttons[index],
                  ],
                ],
              ),
            )
          : Wrap(
              spacing: SpacingTokens.spacing2,
              runSpacing: SpacingTokens.spacing2,
              alignment: WrapAlignment.center,
              children: buttons,
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

class _SelectedSeatLabel extends StatelessWidget {
  const _SelectedSeatLabel({
    required this.selectedSeat,
    required this.maxLines,
  });

  final String selectedSeat;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          selectedSeat,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TypographyTokens.titleMedium(),
        ),
      ],
    );
  }
}

class _SeatMapConsequence extends StatelessWidget {
  const _SeatMapConsequence({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AfriIcons.seat,
              size: 56,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TypographyTokens.headlineSmall(),
            ),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            AfriButton(label: actionLabel, onTap: onAction),
          ],
        ),
      ),
    );
  }
}

class _SeatMapStatus extends StatelessWidget {
  const _SeatMapStatus({
    required this.title,
    required this.body,
    this.tone = AfriStateBannerTone.warning,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final AfriStateBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing4,
        SpacingTokens.spacing2,
        SpacingTokens.spacing4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AfriStateBanner(
            icon: tone == AfriStateBannerTone.danger
                ? AfriIcons.statusError
                : AfriIcons.statusWarning,
            title: title,
            subtitle: body,
            tone: tone,
            compact: true,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            AfriButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
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
