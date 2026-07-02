import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  List<Map<String, String>> _slidesFor(String appName) {
    final label = appName.trim().isEmpty ? 'your club' : appName.trim();
    final normalizedLabel = label.toLowerCase();
    final isRayon =
        normalizedLabel.contains('rayon') ||
        normalizedLabel.contains('gikundiro');
    final mediaAssets = isRayon
        ? const <String>[
            'assets/images/real/rayon-supporters.jpeg',
            'assets/images/real/rayon-match-action.jpeg',
            'assets/images/real/rayon-players-day.jpeg',
          ]
        : const <String>[
            'assets/images/stadium_hero.jpg',
            'assets/images/stadium_hero_2.jpg',
            'assets/images/stadium_hero.jpg',
          ];
    return <Map<String, String>>[
      {
        'title': 'Your club. Your app.',
        'body':
            'The official $label fan platform. Matches, contributions, and more.',
        'asset': mediaAssets[0],
        'source': isRayon ? 'Official supporter media' : 'Club media',
      },
      {
        'title': 'Fan membership. Tickets. Contributions.',
        'body':
            'Earn FET, buy match tickets, and contribute to club projects — all in one place.',
        'asset': mediaAssets[1],
        'source': isRayon ? 'Rayon matchday media' : 'Matchday media',
      },
      {
        'title': 'Ready to play?',
        'body': 'Tickets, merch, and fan communities — all anonymous.',
        'asset': mediaAssets[2],
        'source': isRayon ? 'Rayon player media' : 'Supporter media',
      },
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    if (_isSubmitting) return;

    final authState = ref.read(authStateProvider);
    if (authState is AuthAuthenticated) {
      context.go(_postAuthDestination());
      return;
    }

    setState(() => _isSubmitting = true);
    await ref.read(authStateProvider.notifier).signInAnonymously();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final nextState = ref.read(authStateProvider);
    if (nextState is AuthAuthenticated) {
      context.go(_postAuthDestination());
      return;
    }

    final message = switch (nextState) {
      AuthError() => nextState.message,
      _ => 'Could not start your anonymous session.',
    };

    AfriToast.error(context, message);
  }

  String _postAuthDestination() {
    final raw = _deferredDestination();
    if (raw == null || raw.isEmpty) {
      return '/home';
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path == '/splash' ||
        path == '/onboarding') {
      return '/home';
    }

    return uri.toString();
  }

  String? _deferredDestination() {
    final raw = GoRouterState.of(context).uri.queryParameters['from']?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    final path = uri?.path;
    if (path == null ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path == '/splash' ||
        path == '/onboarding' ||
        path == '/auth/phone') {
      return null;
    }

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        ClubConfigScope.maybeOf(context)?.appName ??
        RuntimeBranding.displayAppName;
    final slides = _slidesFor(appName);
    return Scaffold(
      backgroundColor: ColorTokens.transparent,
      body: GradientBackground(
        routePath: '/onboarding',
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                  },
                  itemBuilder: (context, index) =>
                      _buildSlide(context, slides[index], index),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  0,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing6,
                ),
                child: AfriSurfaceCard(
                  backgroundColor: ColorTokens.surfaceContainerLow.withValues(
                    alpha: 0.82,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                    vertical: SpacingTokens.spacing5,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(
                            slides.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
                              height: 6,
                              width: _currentPage == index ? 28 : 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? ColorTokens.primaryContainer
                                    : ColorTokens.ghostBorder,
                                borderRadius: BorderRadius.circular(
                                  ShapeTokens.radiusFull,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: _isSubmitting
                            ? const Center(child: AfriLoadingIndicator())
                            : AfriButton(
                                label: _currentPage == slides.length - 1
                                    ? 'Get started'
                                    : 'Next',
                                fullWidth: true,
                                onTap: _currentPage == slides.length - 1
                                    ? _handleGetStarted
                                    : () {
                                        unawaited(
                                          _pageController.nextPage(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          ),
                                        );
                                      },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentPage == slides.length - 1)
                Padding(
                  padding: const EdgeInsets.only(
                    left: SpacingTokens.spacing6,
                    right: SpacingTokens.spacing6,
                    bottom: SpacingTokens.spacing6,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AfriTextIconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => context.push(
                              Uri(
                                path: '/auth/phone',
                                queryParameters: <String, String>{
                                  if (_deferredDestination()
                                      case final String from)
                                    'from': from,
                                },
                              ).toString(),
                            ),
                      icon: const Icon(AfriIcons.chat),
                      label: const Text('Continue with WhatsApp'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(
    BuildContext context,
    Map<String, String> slideContent,
    int index,
  ) {
    final icon = switch (index) {
      0 => AfriIcons.stadium,
      1 => AfriIcons.premium,
      _ => AfriIcons.wallet,
    };
    final accent = index == 1 ? ColorTokens.clubAccent : ColorTokens.primary;
    final pageNumber = '${index + 1}'.padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 560;
        final isLargeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
        final shouldScroll = isCompact || isLargeText;
        final mediaHeight = isCompact
            ? 220.0
            : isLargeText
            ? 220.0
            : 280.0;
        final slide = Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            SpacingTokens.spacing4,
            SpacingTokens.spacing6,
            shouldScroll ? SpacingTokens.spacing6 : SpacingTokens.spacing8,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Text(
                  pageNumber,
                  style: TypographyTokens.displayLarge(
                    ColorTokens.primaryContainer.withValues(alpha: 0.14),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: shouldScroll
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: Offset(0, shouldScroll ? 0 : -8),
                    child: AfriSurfaceCard(
                      backgroundColor: ColorTokens.surfaceContainerLow
                          .withValues(alpha: 0.82),
                      height: mediaHeight,
                      width: double.infinity,
                      padding: EdgeInsets.zero,
                      child: _OnboardingMedia(
                        asset: slideContent['asset']!,
                        source: slideContent['source']!,
                        icon: icon,
                        accent: accent,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(
                      0,
                      shouldScroll ? 0 : SpacingTokens.spacing4,
                    ),
                    child: Text(
                      slideContent['title']!,
                      style: TypographyTokens.displaySmall().copyWith(
                        fontSize: shouldScroll ? 32 : 40,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(
                      0,
                      shouldScroll
                          ? SpacingTokens.spacing2
                          : SpacingTokens.spacing3,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        slideContent['body']!,
                        style: TypographyTokens.bodyLarge().copyWith(
                          color: ColorTokens.onSurfaceVariant,
                          fontSize: shouldScroll ? 16 : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (!shouldScroll) {
          return slide;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: slide,
          ),
        );
      },
    );
  }
}

class _OnboardingMedia extends StatelessWidget {
  const _OnboardingMedia({
    required this.asset,
    required this.source,
    required this.icon,
    required this.accent,
  });

  final String asset;
  final String source;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: ColorTokens.heroGradient(
                  from: accent,
                  to: ColorTokens.primaryContainer,
                ),
              ),
              child: Icon(icon, size: 56, color: ColorTokens.onSurface),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: ColorTokens.imageScrimGradient(
                color: ColorTokens.background,
                alphas: const [0.0, 0.08, 0.55, 0.78],
                stops: const [0.0, 0.32, 0.72, 1.0],
              ),
            ),
          ),
          Positioned(
            left: SpacingTokens.spacing5,
            right: SpacingTokens.spacing5,
            bottom: SpacingTokens.spacing5,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ColorTokens.primaryContainer,
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                  ),
                  child: Icon(icon, color: ColorTokens.onSurface, size: 22),
                ),
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(
                  child: Text(
                    source.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypographyTokens.labelSmall(
                      ColorTokens.onDark,
                    ).copyWith(letterSpacing: 1.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
