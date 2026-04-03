import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../ticketing_providers.dart';

class ETicketQrScreen extends ConsumerStatefulWidget {
  const ETicketQrScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<ETicketQrScreen> createState() => _ETicketQrScreenState();
}

class _ETicketQrScreenState extends ConsumerState<ETicketQrScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(myTicketProvider(widget.ticketId));

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: ticketAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriSkeletonList(),
        ),
        error: (error, _) => const _QrState(
          title: 'Ticket unavailable',
          body: 'This ticket could not be loaded from your wallet.',
        ),
        data: (ticket) {
          if (ticket == null) {
            return const _QrState(
              title: 'Ticket not found',
              body: 'E-ticket unavailable.',
            );
          }

          final code = ticket.qrCode.isNotEmpty ? ticket.qrCode : ticket.id;

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield,
                    size: 48,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    ticket.matchTitle,
                    style: TypographyTokens.headlineSmall(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SpacingTokens.spacing6),
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    decoration: BoxDecoration(
                      color: ColorTokens.surface,
                      borderRadius: ShapeTokens.cardRadius,
                      border: Border.all(color: ColorTokens.ghostBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 260,
                              height: 260,
                              decoration: BoxDecoration(
                                color: ColorTokens.onSurface,
                                borderRadius: BorderRadius.circular(
                                  SpacingTokens.spacing2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: QrImageView(
                                data: code,
                                size: 220,
                                backgroundColor: ColorTokens.onSurface,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: ColorTokens.background,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: ColorTokens.background,
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _scannerController,
                              builder: (context, child) {
                                return Positioned(
                                  top: _scannerController.value * 240,
                                  child: Container(
                                    width: 260,
                                    height: 2,
                                    color: ColorTokens.clubPrimary,
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: ColorTokens.clubPrimary
                                              .withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: SpacingTokens.spacing6),
                        Text(
                          ticket.seatType.label.toUpperCase(),
                          style: TypographyTokens.headlineMedium().copyWith(
                            color: ColorTokens.clubAccent,
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          AfriDateFormatter.formatDate(ticket.match.matchDate),
                          style: TypographyTokens.bodyMedium(),
                        ),
                        Text(
                          ticket.match.venue,
                          style: TypographyTokens.bodyMedium().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Text(
                          'Ticket code: $code',
                          style: TypographyTokens.numericAlias(fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: SpacingTokens.spacing10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_tethering,
                        color: ColorTokens.onSurfaceVariant,
                      ),
                      const SizedBox(width: SpacingTokens.spacing2),
                      Text(
                        'Present this QR code at the gate',
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QrState extends StatelessWidget {
  const _QrState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_outlined,
              size: 56,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(title, style: TypographyTokens.headlineSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
          ],
        ),
      ),
    );
  }
}
