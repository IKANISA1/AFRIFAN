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
                  EliteCard(
                    backgroundColor: Colors.white,
                    borderColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Upper Pass: QR Code
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: QrImageView(
                                  data: code,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
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
                          children: List.generate(20, (i) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 1,
                              color: Colors.black12,
                            ),
                          )),
                        ),

                        // Lower Pass: Details
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Text(
                                ticket.matchTitle.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Display',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ColorTokens.clubAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ticket.seatType.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: ColorTokens.clubAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildPassMeta('DATE', AfriDateFormatter.formatDate(ticket.match.matchDate)),
                                  _buildPassMeta('TIME', ticket.match.kickoffTime ?? '18:00'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildPassMeta('VENUE', ticket.match.venue.toUpperCase()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: EliteButton(
                          label: 'Apple Wallet',
                          onTap: () {},
                          variant: EliteButtonVariant.outline,
                          icon: Icons.add_card_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EliteButton(
                          label: 'Google Wallet',
                          onTap: () {},
                          variant: EliteButtonVariant.outline,
                          icon: Icons.wallet_rounded,
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

  Widget _buildPassMeta(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5),
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
