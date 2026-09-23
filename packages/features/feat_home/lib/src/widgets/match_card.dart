import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Keeps carousel content legible when the user enlarges text.
double homeHeroHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
  return 252 * scale;
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
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: homeHeroHeight(context)),
              child: AfriPressFeedback(
                onTap: slide.route == null
                    ? null
                    : () => context.push(slide.route!),
                semanticsLabel: context.afriL10n.homeOpenMatchDetails,
                child: _MatchOverview(slide: slide),
              ),
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
    final colors = context.afriSemanticColors;
    final hasScore = slide.homeScore != null && slide.awayScore != null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.screenPadding,
        vertical: SpacingTokens.spacing4,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slide.status.isNotEmpty) ...[
            Text(
              slide.status,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyLarge(colors.primaryText),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
          ],
          AfriFixtureTeams(homeTeam: slide.homeTeam, awayTeam: slide.awayTeam,
            score: hasScore ? '${slide.homeScore}–${slide.awayScore}' : null, crestSize: 40),
          const SizedBox(height: SpacingTokens.spacing3),
          if (slide.dateInfo.isNotEmpty)
            Text(
              slide.dateInfo,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(colors.primaryText),
            ),
          if (slide.venue.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              slide.venue,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodySmall(colors.primaryText),
            ),
          ],
        ],
      ),
    );
  }
}
