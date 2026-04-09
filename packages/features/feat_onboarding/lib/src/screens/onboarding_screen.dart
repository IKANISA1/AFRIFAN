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
      backgroundColor: ColorTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Placeholder for slide illustration
                        ClayCard(
                          height: 200,
                          width: double.infinity,
                          backgroundColor: ColorTokens.surface,
                          child: Center(
                            child: Icon(
                              index == 0
                                  ? Icons.stadium_outlined
                                  : (index == 1
                                        ? Icons.security_outlined
                                        : Icons
                                              .account_balance_wallet_outlined),
                              size: 80,
                              color: ColorTokens.clubPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: SpacingTokens.spacing10),
                        Text(
                          _slides[index]['title']!,
                          style: TypographyTokens.headlineLarge(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: SpacingTokens.spacing4),
                        Text(
                          _slides[index]['body']!,
                          style: TypographyTokens.bodyLarge().copyWith(
                            color: ColorTokens.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 6,
                        width: _currentPage == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? ColorTokens.clubPrimary
                              : ColorTokens.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  _currentPage == _slides.length - 1
                      ? _isSubmitting
                            ? SizedBox(
                                width: 150,
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ColorTokens.clubPrimary,
                                    ),
                                  ),
                                ),
                              )
                            : ClaymorphicButton(
                                label: 'GET STARTED',
                                onPressed: _handleGetStarted,
                              )
                      : TextButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Text(
                            'NEXT',
                            style: TypographyTokens.labelLarge().copyWith(
                              color: ColorTokens.onSurface,
                            ),
                          ),
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
