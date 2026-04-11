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

  // §2.4 LOCKED — no hardcoded club names. Use compile-time constant.
  static const _appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Gikundiro',
  );

  final List<Map<String, String>> _slides = [
    {
      'title': 'YOUR CLUB. YOUR APP.',
      'body':
          'The official $_appName fan platform. Matches, contributions, and more.',
    },
    {
      'title': 'FAN MEMBERSHIP. TICKETS. CONTRIBUTIONS.',
      'body':
          'Earn XP, buy match tickets, and contribute to club projects — all in one place.',
    },
    {
      'title': 'READY TO PLAY?',
      'body': 'Tickets, merch, and fan communities — all anonymous.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    final authState = ref.read(authStateProvider);
    if (authState is AuthAuthenticated) {
      // §2.2 LOCKED — no MOMO gate on launch. Always go to /home.
      context.go('/home');
      return;
    }

    setState(() => _isSubmitting = true);
    await ref.read(authStateProvider.notifier).signInAnonymously();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final nextState = ref.read(authStateProvider);
    if (nextState is AuthAuthenticated) {
      // §2.2 LOCKED — go straight to home after anonymous sign-in.
      context.go('/home');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                  },
                  itemBuilder: (context, index) => _buildSlide(context, index),
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
                            _slides.length,
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
                            : ClaymorphicButton(
                                label: _currentPage == _slides.length - 1
                                    ? 'GET STARTED'
                                    : 'NEXT',
                                width: double.infinity,
                                onPressed: _currentPage == _slides.length - 1
                                    ? _handleGetStarted
                                    : () {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(BuildContext context, int index) {
    final icon = switch (index) {
      0 => Icons.stadium_outlined,
      1 => Icons.workspace_premium_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
    final accent = index == 1 ? ColorTokens.clubAccent : ColorTokens.primary;
    final pageNumber = '${index + 1}'.padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        SpacingTokens.spacing4,
        SpacingTokens.spacing6,
        SpacingTokens.spacing8,
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -8),
                child: GlassCard(
                  height: 280,
                  width: double.infinity,
                  padding: const EdgeInsets.all(SpacingTokens.spacing8),
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
                          'OFFICIAL SUPPORTER OS',
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
                          width: 124,
                          height: 124,
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
                          child: Icon(icon, size: 52, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Text(
                  _slides[index]['title']!,
                  style: TypographyTokens.displaySmall().copyWith(
                    fontSize: 40,
                    height: 0.95,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    _slides[index]['body']!,
                    style: TypographyTokens.bodyLarge().copyWith(
                      color: ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
