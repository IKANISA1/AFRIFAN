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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.close,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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

          if (ticket.status == TicketStatus.pending) {
            return const _QrState(
              title: 'Payment verification pending',
              body:
                  'This ticket request was recorded, but the QR code will only unlock after payment verification completes.',
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
                  AfriPanelCard(
                    backgroundColor: ColorTokens.borrowedPaper,
                    borderColor: ColorTokens.transparent,
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Upper Pass: QR Code
                        Padding(
                          padding: const EdgeInsets.all(SpacingTokens.spacing8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: BorderTokens.all(
                                    color: ColorTokens.borrowedInk,
                                    opacity: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    ShapeTokens.radiusSm,
                                  ),
                                ),
                                child: QrImageView(
                                  data: code,
                                  size: 220,
                                  backgroundColor: ColorTokens.borrowedPaper,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: ColorTokens.borrowedInk,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: ColorTokens.borrowedInk,
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _scannerController,
                                builder: (context, child) {
                                  return Positioned(
                                    top: _scannerController.value * 220,
                                    child: Container(
                                      width: 220,
                                      height: 2,
                                      color: ColorTokens.clubPrimary,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Perforated Divider
                        Row(
                          children: List.generate(
                            20,
                            (i) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: SpacingTokens.spacing1 / 2,
                                ),
                                height: BorderTokens.hairline,
                                color: ColorTokens.borrowedHairline,
                              ),
                            ),
                          ),
                        ),

                        // Lower Pass: Details
                        Padding(
                          padding: const EdgeInsets.all(SpacingTokens.spacing8),
                          child: Column(
                            children: [
                              Text(
                                ticket.matchTitle.toUpperCase(),
                                style: TypographyTokens.headlineMedium(
                                  ColorTokens.borrowedInk,
                                ).copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpacingTokens.spacing3,
                                  vertical: SpacingTokens.spacing1,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorTokens.clubAccent
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    ShapeTokens.radiusSm,
                                  ),
                                ),
                                child: Text(
                                  ticket.seatType.label.toUpperCase(),
                                  style: TypographyTokens.titleMedium(
                                    ColorTokens.clubAccent,
                                  ).copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: SpacingTokens.spacing6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildPassMeta(
                                      'DATE',
                                      AfriDateFormatter.formatDate(
                                          ticket.match.matchDate)),
                                  _buildPassMeta(
                                    'TIME',
                                    ticket.match.kickoffTime,
                                  ),
                                ],
                              ),
                              const SizedBox(height: SpacingTokens.spacing4),
                              _buildPassMeta(
                                  'VENUE', ticket.match.venue.toUpperCase()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: SpacingTokens.spacing8),
                  Row(
                    children: [
                      Expanded(
                        child: AfriButton(
                          label: 'Apple Wallet',
                          onTap: () {},
                          variant: AfriButtonVariant.outline,
                          icon: AfriIcons.addCard,
                          enabled: false,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      Expanded(
                        child: AfriButton(
                          label: 'Google Wallet',
                          onTap: () {},
                          variant: AfriButtonVariant.outline,
                          icon: AfriIcons.wallet,
                          enabled: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    'Wallet export is not available in this release yet.',
                    style: TypographyTokens.bodySmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassMeta(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TypographyTokens.labelSmall(
            ColorTokens.borrowedInkFaint,
          ).copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1 / 2),
        Text(
          value,
          style: TypographyTokens.labelMedium(
            ColorTokens.borrowedInk,
          ).copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
              AfriIcons.qrCode,
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
