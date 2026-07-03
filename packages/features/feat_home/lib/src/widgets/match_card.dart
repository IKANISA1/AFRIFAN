// ╔══════════════════════════════════════════════════════════════════╗
// ║  ⛔ LOCKED FILE — HERO SECTION FRONTEND IS FROZEN              ║
// ║  DO NOT modify the visual layout, structure, sizing,           ║
// ║  typography, or widget tree of MatchScoreCard / _HeroSlide.    ║
// ║  Only backend data changes (routes, URLs, slide content)       ║
// ║  are permitted. See /HERO_LOCK.md for full rules.              ║
// ║  Approved: 2026-03-30 by Product Owner.                        ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A single match/event slide — CMS-managed, admin-controlled.
class MatchSlide {
  final String? imageUrl;
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
    // §2.4 LOCKED — no hardcoded club/venue names.
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

/// Hero event card — floating rounded card on dark background.
///
/// Reference shape analysis:
/// - Small horizontal margin (~16px) on left/right
/// - Rounded corners all around (~20px)
/// - Card floats/is detached from the background
/// - Image fills the card, clipped by rounded corners
/// - Uses ClipRRect plus margin instead of a custom clipper.
class MatchScoreCard extends StatefulWidget {
  final List<MatchSlide> slides;
  final Duration autoSlideInterval;

  const MatchScoreCard({
    super.key,
    // §2.4 LOCKED — default slides load from CMS; empty list = no hero.
    this.slides = const [],
    this.autoSlideInterval = const Duration(seconds: 5),
  });

  @override
  State<MatchScoreCard> createState() => _MatchScoreCardState();
}

class _MatchScoreCardState extends State<MatchScoreCard> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  static Color get _heroAccent => ColorTokens.clubPrimary;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.slides.length > 1) _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(widget.autoSlideInterval, (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.slides.length;
      unawaited(
        _pageController.animateToPage(
          next,
          duration: AfriMotion.atmospheric,
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.333,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Sliding image pages ──
          PageView.builder(
            controller: _pageController,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) {
              final slide = widget.slides[i];
              return AfriPressFeedback(
                onTap: slide.route == null
                    ? null
                    : () => unawaited(context.push(slide.route!)),
                haptic: slide.route != null,
                scaleEnd: 0.99,
                opacityEnd: 0.98,
                semanticsLabel: 'Open match details',
                tooltip: 'Open match details',
                excludeChildSemantics: false,
                child: _HeroSlide(slide: slide, accentColor: _heroAccent),
              );
            },
          ),

          // ── Page indicator dots (bottom center) ──
          if (widget.slides.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.slides.length,
                  (i) => AnimatedContainer(
                    duration: AfriMotion.standard,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 24 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? _heroAccent
                          : ColorTokens.onDarkSoft,
                      borderRadius: BorderRadius.circular(
                        ShapeTokens.radiusSm / 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single hero slide — full-bleed image with text overlay.
class _HeroSlide extends StatelessWidget {
  final MatchSlide slide;
  final Color accentColor;

  const _HeroSlide({required this.slide, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background image ──
        _buildBackground(),

        // ── Gradient overlay (using primary as allowed) ──
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: ColorTokens.imageScrimGradient(
              color: ColorTokens.clubPrimary,
              alphas: const [0.0, 0.27, 0.8, 1.0],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),

        // ── Content overlay ──
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 4),

                // ── Massive team names ──
                // Forced to exactly 2 lines using explicit \n and softWrap: false.
                // FittedBox dynamically scales the text down if "TEAM A VS" is too wide.
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      softWrap: false,
                      maxLines: 2,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${slide.homeTeam.toUpperCase()} ',
                            style:
                                TypographyTokens.displayLarge(
                                  ColorTokens.onDark,
                                ).copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 0.90,
                                  letterSpacing: 0,
                                ),
                          ),
                          TextSpan(
                            text: 'VS\n',
                            style: TypographyTokens.displayLarge(accentColor)
                                .copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 0.90,
                                  letterSpacing: 0,
                                ),
                          ),
                          TextSpan(
                            text: slide.awayTeam.toUpperCase(),
                            style:
                                TypographyTokens.displayLarge(
                                  ColorTokens.onDark,
                                ).copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 0.90,
                                  letterSpacing: 0,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Date/time row ──
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slide.dateInfo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TypographyTokens.bodyLarge(
                              ColorTokens.onDarkSubtle,
                            ).copyWith(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ), // End SafeArea
      ],
    );
  }

  Widget _buildBackground() {
    if (slide.imageUrl != null && slide.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: slide.imageUrl!,
        cacheManager: AfriImageCacheManager.instance,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _gradient(),
        errorWidget: (_, __, ___) => _gradient(),
      );
    }
    return _gradient();
  }

  Widget _gradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: ColorTokens.universalGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorTokens.surfaceContainerHigh,
            ColorTokens.clubPrimary.withValues(alpha: 0.3),
          ],
        ),
      ),
    );
  }
}
