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
    final hero = slides.first;
    return Scaffold(
      backgroundColor: ColorTokens.transparent,
      body: GradientBackground(
        routePath: '/onboarding',
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 620;
              final isLargeText =
                  MediaQuery.textScalerOf(context).scale(1) > 1.45;
              final mediaHeight = isCompact || isLargeText ? 210.0 : 280.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing6,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - SpacingTokens.spacing10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AfriSurfaceCard(
                        backgroundColor: ColorTokens.surfaceContainerLow
                            .withValues(alpha: 0.82),
                        height: mediaHeight,
                        width: double.infinity,
                        padding: EdgeInsets.zero,
                        child: _OnboardingMedia(
                          asset: hero['asset']!,
                          source: hero['source']!,
                          icon: AfriIcons.stadium,
                          accent: ColorTokens.primary,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing6),
                      Text(
                        'Your club. Your app.',
                        style: TypographyTokens.displaySmall().copyWith(
                          fontSize: isCompact ? 32 : 40,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Text(
                        'The official $appName fan platform for matchday, membership, tickets, and support.',
                        style: TypographyTokens.bodyLarge(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing6),
                      const _OnboardingHighlightGrid(
                        highlights: [
                          _OnboardingHighlightData(
                            icon: AfriIcons.membership,
                            title: 'Membership',
                            subtitle: 'Fan ID and benefits',
                          ),
                          _OnboardingHighlightData(
                            icon: AfriIcons.tickets,
                            title: 'Tickets',
                            subtitle: 'Matchday access',
                          ),
                          _OnboardingHighlightData(
                            icon: AfriIcons.contribute,
                            title: 'Support',
                            subtitle: 'Projects and groups',
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing6),
                      _isSubmitting
                          ? const Center(child: AfriLoadingIndicator())
                          : AfriButton(
                              label: 'Get started',
                              fullWidth: true,
                              onTap: _handleGetStarted,
                            ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Align(
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
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingHighlightData {
  const _OnboardingHighlightData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _OnboardingHighlightGrid extends StatelessWidget {
  const _OnboardingHighlightGrid({required this.highlights});

  final List<_OnboardingHighlightData> highlights;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRows = textScale > 1.35 || constraints.maxWidth < 340;
        if (useRows) {
          return Column(
            children: highlights
                .map(
                  (highlight) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: SpacingTokens.listItemGap,
                    ),
                    child: _OnboardingHighlight(data: highlight, wide: true),
                  ),
                )
                .toList(growable: false),
          );
        }

        return Wrap(
          spacing: SpacingTokens.listItemGap,
          runSpacing: SpacingTokens.listItemGap,
          children: highlights
              .map(
                (highlight) => SizedBox(
                  width: 104,
                  child: _OnboardingHighlight(data: highlight),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _OnboardingHighlight extends StatelessWidget {
  const _OnboardingHighlight({required this.data, this.wide = false});

  final _OnboardingHighlightData data;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(data.icon, size: 20, color: ColorTokens.primaryContainer);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          maxLines: wide ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TypographyTokens.labelMedium().copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        Text(
          data.subtitle,
          maxLines: wide ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
        ),
      ],
    );

    return AfriSurfaceCard(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: SpacingTokens.spacing3),
                Expanded(child: copy),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(height: SpacingTokens.spacing3),
                copy,
              ],
            ),
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
