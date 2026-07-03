import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VenueCheckinScreen extends StatefulWidget {
  const VenueCheckinScreen({super.key});

  @override
  State<VenueCheckinScreen> createState() => _VenueCheckinScreenState();
}

class _VenueCheckinScreenState extends State<VenueCheckinScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _locationRequested = false;
  String _statusCode = 'ready';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _codeController.text.trim();
    setState(() {
      _statusCode = code.length < 4 ? 'invalid_code' : 'pending_review';
    });
  }

  void _requestLocationVerification() {
    setState(() {
      _locationRequested = true;
      _statusCode = 'location_pending';
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _venueStatusFor(_statusCode);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('Venue check-in', style: TypographyTokens.headlineSmall()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          children: [
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AfriIcons.qrScan,
                    color: ColorTokens.clubAccent,
                    size: SpacingTokens.spacing10,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  Text(
                    'Check in at an approved venue',
                    style: TypographyTokens.headlineLarge().copyWith(
                      fontWeight: FontWeight.w900,
                      height: TypographyTokens.lineHeightCompact,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    'Use the rotating TV or QR code after you arrive. Staff and admin operations are never available in the supporter app.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Venue code', style: TypographyTokens.titleLarge()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriInputField(
                    controller: _codeController,
                    label: 'TV or QR code',
                    keyboardType: TextInputType.visiblePassword,
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    label: 'Check in',
                    icon: AfriIcons.qrCode,
                    onTap: _submitCode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optional location',
                    style: TypographyTokens.titleLarge(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(
                    _locationRequested
                        ? 'Location verification is pending for this check-in only.'
                        : 'Location is requested only after you start check-in or choose nearby venue discovery.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  AfriButton(
                    label: _locationRequested
                        ? 'Location pending'
                        : 'Verify location',
                    icon: AfriIcons.location,
                    variant: AfriButtonVariant.secondary,
                    enabled: !_locationRequested,
                    onTap: _requestLocationVerification,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            AfriStateBanner(
              icon: status.icon,
              title: status.title,
              subtitle: status.subtitle,
              tone: status.tone,
            ),
            const SizedBox(height: SpacingTokens.sectionGap),
            const AfriSectionCard(
              title: 'Covered states',
              child: Column(
                children: [
                  _StateRow(label: 'Expired code', detail: 'Handled by server'),
                  _StateRow(label: 'Already checked in', detail: 'Idempotent'),
                  _StateRow(label: 'Promo paused', detail: 'Fails closed'),
                  _StateRow(label: 'Too far', detail: 'Review state'),
                  _StateRow(
                    label: 'Alcohol items',
                    detail: 'Age gate required',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
      child: Row(
        children: [
          const Icon(
            AfriIcons.statusSuccess,
            color: ColorTokens.success,
            size: AfriIcons.sizeInline,
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(child: Text(label, style: TypographyTokens.titleSmall())),
          Text(detail, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}

class _VenueStatus {
  const _VenueStatus({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AfriStateBannerTone tone;
}

_VenueStatus _venueStatusFor(String code) {
  switch (code) {
    case 'invalid_code':
      return const _VenueStatus(
        title: 'Code needs review',
        subtitle: 'Enter the current TV or QR code shown at the venue.',
        icon: AfriIcons.statusWarning,
        tone: AfriStateBannerTone.warning,
      );
    case 'pending_review':
      return const _VenueStatus(
        title: 'Check-in queued',
        subtitle:
            'The backend validates expiry, duplicate use, and campaign limits.',
        icon: AfriIcons.statusInfo,
        tone: AfriStateBannerTone.info,
      );
    case 'location_pending':
      return const _VenueStatus(
        title: 'Location check pending',
        subtitle:
            'Foreground location is optional verification for this check-in only.',
        icon: AfriIcons.location,
        tone: AfriStateBannerTone.info,
      );
    default:
      return const _VenueStatus(
        title: 'Ready for venue check-in',
        subtitle: 'Scan or enter the venue code when you are on site.',
        icon: AfriIcons.qrCode,
        tone: AfriStateBannerTone.neutral,
      );
  }
}
