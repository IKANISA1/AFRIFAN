import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Keeps carousel content legible when the user enlarges text.
double homeHeroHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
  return 300 * scale;
}

/// A single match/event slide — CMS-managed, admin-controlled.
class MatchSlide {
  final String? imageUrl;
  final String? imageProvenanceId;
  final bool imageRightsApproved;
  final String homeTeam;
  final String awayTeam;
  final String venue;
  final String status;
  final String dateInfo;
  final int? homeScore;
  final int? awayScore;

  /// Route to navigate to when this slide is tapped (e.g. '/tickets/detail/1').
  final String? route;

  const MatchSlide({
    this.imageUrl,
    this.imageProvenanceId,
    this.imageRightsApproved = false,
    this.homeTeam = '',
    this.awayTeam = '',
    this.venue = '',
    this.status = '',
    this.dateInfo = '',
    this.homeScore,
    this.awayScore,
    this.route,
  });
}

/// Centred match identity on the overview glow (LIVE-020/021 pattern).
/// The carousel is user-controlled, so scores never move while being read.
class MatchScoreCard extends StatefulWidget {
  const MatchScoreCard({super.key, this.slides = const []});
  final List<MatchSlide> slides;

  @override
  State<MatchScoreCard> createState() => _MatchScoreCardState();
}

class _MatchScoreCardState extends State<MatchScoreCard> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    // Large text keeps the complete object in the main vertical scroll flow.
    // A one-item carousel also needs no fixed viewport or page machinery.
    if (widget.slides.length == 1 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        children: [
          for (final slide in widget.slides)
            AfriPressFeedback(
              onTap: slide.route == null
                  ? null
                  : () => context.push(slide.route!),
              semanticsLabel: context.afriL10n.homeOpenMatchDetails,
              child: _MatchOverview(slide: slide),
            ),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(
          height: homeHeroHeight(context),
          child: PageView.builder(
            itemCount: widget.slides.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final slide = widget.slides[index];
              return AfriPressFeedback(
                onTap: slide.route == null
                    ? null
                    : () => context.push(slide.route!),
                semanticsLabel: context.afriL10n.homeOpenMatchDetails,
                child: _MatchOverview(slide: slide),
              );
            },
          ),
        ),
        if (widget.slides.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.slides.length,
              (index) => Container(
                margin: const EdgeInsets.all(4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.onSurface.withValues(
                    alpha: index == _currentPage ? 1 : 0.3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MatchOverview extends StatelessWidget {
  const _MatchOverview({required this.slide});
  final MatchSlide slide;

  @override
  Widget build(BuildContext context) {
    final hasScore = slide.homeScore != null && slide.awayScore != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.screenPadding,
        SpacingTokens.spacing3,
        SpacingTokens.screenPadding,
        SpacingTokens.spacing5,
      ),
      child: AfriEditorialCard(
        lightSurface: true,
        imageRightsApproved: slide.imageRightsApproved,
        imageProvenanceId: slide.imageProvenanceId,
        imageUrl:
            slide.imageRightsApproved &&
                (slide.imageProvenanceId?.trim().isNotEmpty ?? false)
            ? slide.imageUrl
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (slide.status.isNotEmpty) ...[
              Text(
                slide.status,
                style: TypographyTokens.labelLarge(ColorTokens.discoveryInk),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
            ],
            AfriFixtureTeams(
              homeTeam: slide.homeTeam,
              awayTeam: slide.awayTeam,
              score: hasScore ? '${slide.homeScore}–${slide.awayScore}' : null,
              foreground: ColorTokens.discoveryInk,
              crestSize: 40,
            ),
            if (slide.dateInfo.isNotEmpty || slide.venue.isNotEmpty) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                [
                  slide.dateInfo,
                  slide.venue,
                ].where((s) => s.isNotEmpty).join(' · '),
                textAlign: TextAlign.center,
                style: TypographyTokens.bodySmall(ColorTokens.discoveryInk),
              ),
            ],
            if (slide.route != null) ...[
              const SizedBox(height: SpacingTokens.spacing4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      context.afriL10n.homeViewMatch,
                      style: TypographyTokens.labelLarge(
                        ColorTokens.discoveryInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing2),
                  const Icon(
                    AfriIcons.chevronRight,
                    color: ColorTokens.discoveryInk,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
