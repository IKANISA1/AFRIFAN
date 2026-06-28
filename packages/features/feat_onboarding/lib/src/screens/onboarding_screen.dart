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
    return <Map<String, String>>[
      {
        'title': 'Your club. Your app.',
        'body':
            'The official $label fan platform. Matches, contributions, and more.',
      },
      {
        'title': 'Fan membership. Tickets. Contributions.',
        'body':
            'Earn FET, buy match tickets, and contribute to club projects — all in one place.',
      },
      {
        'title': 'Ready to play?',
        'body': 'Tickets, merch, and fan communities — all anonymous.',
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      backgroundColor: Colors.transparent,
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
                child: GlassCard(
                  animate: false,
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
                            ? const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
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
                    child: TextButton.icon(
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
                      label: const Text('Use phone / WhatsApp OTP'),
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
        final slide = Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            SpacingTokens.spacing4,
            SpacingTokens.spacing6,
            isCompact ? SpacingTokens.spacing6 : SpacingTokens.spacing8,
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
                mainAxisAlignment: isCompact
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: Offset(0, isCompact ? 0 : -8),
                    child: GlassCard(
                      height: isCompact ? 220 : 280,
                      width: double.infinity,
                      padding: EdgeInsets.all(
                        isCompact
                            ? SpacingTokens.spacing6
                            : SpacingTokens.spacing8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SpacingTokens.spacing4,
                              vertical: SpacingTokens.spacing2,
                            ),
                            decoration: BoxDecoration(
                              color: ColorTokens.secondaryContainer,
                              borderRadius: ShapeTokens.chipRadius,
                            ),
                            child: Text(
                              'Official Supporter OS',
                              style: TypographyTokens.labelSmall().copyWith(
                                color: ColorTokens.onSurface,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: isCompact ? 104 : 124,
                              height: isCompact ? 104 : 124,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: ColorTokens.heroGradient(
                                  from: accent,
                                  to: ColorTokens.primaryContainer,
                                ),
                                boxShadow: [
                                  ...AfriShadows.primaryGlow(
                                    ColorTokens.primaryContainer,
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: isCompact ? 44 : 52,
                                color: ColorTokens.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, isCompact ? -12 : -28),
                    child: Text(
                      slideContent['title']!,
                      style: TypographyTokens.displaySmall().copyWith(
                        fontSize: isCompact ? 32 : 40,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, isCompact ? -4 : -12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        slideContent['body']!,
                        style: TypographyTokens.bodyLarge().copyWith(
                          color: ColorTokens.onSurfaceVariant,
                          fontSize: isCompact ? 16 : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (!isCompact) {
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
