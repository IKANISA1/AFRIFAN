import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../onboarding_content_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    this.mediaRightsApproved = const bool.fromEnvironment(
      'CLUB_ONBOARDING_MEDIA_RIGHTS_APPROVED',
      defaultValue: false,
    ),
    super.key,
  });

  /// Release-controlled approval for the documented onboarding photographs.
  ///
  /// The default is fail-closed. Store/release builds may enable this only
  /// after the exact files and sources in `assets/onboarding/SOURCES.md` have
  /// accountable right-to-use approval.
  final bool mediaRightsApproved;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isSubmitting = false;
  final PageController _pageController = PageController();
  Timer? _slideTimer;
  int _currentSlide = 0;

  List<_WelcomeSlide> _slidesFor({
    required String appName,
    required String clubName,
    required AfriLocalizations l10n,
    required List<OnboardingSlideId> slideIds,
  }) {
    final appLabel = appName.trim().isEmpty ? clubName.trim() : appName.trim();
    final clubLabel = clubName.trim().isEmpty ? appLabel : clubName.trim();
    return slideIds
        .map((id) {
          return switch (id) {
            OnboardingSlideId.belong => _WelcomeSlide(
              imagePath: 'assets/onboarding/rayon_matchday_team.webp',
              title: l10n.onboardingBelongTitle,
              body: l10n.onboardingBelongBody(clubLabel),
              semanticLabel: l10n.onboardingBelongImageSemantic(clubLabel),
            ),
            OnboardingSlideId.know => _WelcomeSlide(
              imagePath: 'assets/onboarding/rayon_players_celebrating.webp',
              title: l10n.onboardingKnowTitle,
              body: l10n.onboardingKnowBody(appLabel),
              semanticLabel: l10n.onboardingKnowImageSemantic(clubLabel),
            ),
            OnboardingSlideId.live => _WelcomeSlide(
              imagePath: 'assets/onboarding/rayon_new_signing.webp',
              title: l10n.onboardingLiveTitle,
              body: l10n.onboardingLiveBody,
              semanticLabel: l10n.onboardingLiveImageSemantic(clubLabel),
            ),
          };
        })
        .toList(growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slideTimer?.cancel();
    if (!AfriMotion.reduceMotion(context)) {
      _slideTimer = Timer.periodic(AfriMotion.carouselInterval, (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_currentSlide + 1) % 3;
        unawaited(
          _pageController.animateToPage(
            next,
            duration: AfriMotion.resolve(
              context,
              AfriMotion.carouselTransition,
            ),
            curve: Curves.easeInOutCubic,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleHorizontalDragEnd(DragEndDetails details, int slideCount) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120 || !_pageController.hasClients) return;
    final next = velocity < 0
        ? (_currentSlide + 1).clamp(0, slideCount - 1)
        : (_currentSlide - 1).clamp(0, slideCount - 1);
    if (next == _currentSlide) return;
    if (AfriMotion.reduceMotion(context)) {
      _pageController.jumpToPage(next);
      return;
    }
    unawaited(
      _pageController.animateToPage(
        next,
        duration: AfriMotion.emphasized,
        curve: AfriMotion.enterCurve,
      ),
    );
  }

  Future<void> _continueWithoutSignIn() async {
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

    AfriToast.error(
      context,
      context.afriL10n.onboardingAnonymousSessionUnavailable,
    );
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
    final l10n = context.afriL10n;
    final clubConfig = ClubConfigScope.maybeOf(context);
    final appName = clubConfig?.appName ?? RuntimeBranding.displayAppName;
    final clubName = clubConfig?.clubName ?? RuntimeBranding.displayClubName;
    final asyncContent = ref.watch(onboardingContentProvider);
    final snapshot = asyncContent.valueOrNull;

    if (snapshot == null || snapshot.isEmpty) {
      return _OnboardingContentState(
        clubName: clubName,
        state: asyncContent,
        isEmpty: snapshot?.isEmpty ?? false,
        onRefresh: () => ref.read(onboardingContentProvider.notifier).refresh(),
        onSignIn: () => context.push(
          Uri(
            path: '/auth/phone',
            queryParameters: <String, String>{
              if (_deferredDestination() case final String from) 'from': from,
            },
          ).toString(),
        ),
        onSkip: _continueWithoutSignIn,
      );
    }

    final slides = _slidesFor(
      appName: appName,
      clubName: clubName,
      l10n: l10n,
      slideIds: snapshot.slides,
    );
    final statusMessage = switch (snapshot.notice) {
      OnboardingContentNotice.offlineSaved =>
        l10n.onboardingOfflineSavedMessage,
      OnboardingContentNotice.whatsAppUnavailable =>
        l10n.onboardingWhatsAppLaterMessage,
      null => null,
    };
    final safeCurrentSlide = _currentSlide.clamp(0, slides.length - 1);
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.referenceChromeBlack,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (index) => setState(() => _currentSlide = index),
            itemBuilder: (context, index) => _WelcomeBackground(
              key: ValueKey(slides[index].imagePath),
              slide: slides[index],
              index: index,
              count: slides.length,
              rightsApproved: widget.mediaRightsApproved,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: ColorTokens.imageScrimGradient(
                color: ColorTokens.referenceChromeBlack,
                alphas: const [0.12, 0.05, 0.55, 0.96],
                stops: const [0.0, 0.38, 0.67, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: SizedBox(
                key: const ValueKey<String>('onboarding-responsive-content'),
                width: AfriResponsive.maxContentWidthForWidth(
                  MediaQuery.sizeOf(context).width,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) =>
                      _handleHorizontalDragEnd(details, slides.length),
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isLargeText =
                            MediaQuery.textScalerOf(context).scale(16) >= 24;
                        final isCompact =
                            constraints.maxHeight < 620 || isLargeText;
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            SpacingTokens.spacing6,
                            SpacingTokens.spacing4,
                            SpacingTokens.spacing6,
                            isCompact
                                ? SpacingTokens.spacing2
                                : SpacingTokens.spacing5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  AfriBrandMark(
                                    label: clubName,
                                    size: isCompact ? 46 : 56,
                                    borderRadius: BorderRadius.circular(
                                      ShapeTokens.radiusMd,
                                    ),
                                    semanticLabel: l10n
                                        .onboardingIdentitySemantic(clubName),
                                  ),
                                  const Spacer(),
                                  Semantics(
                                    label: l10n.onboardingWelcomeImage(
                                      _currentSlide + 1,
                                      slides.length,
                                    ),
                                    liveRegion: true,
                                    child: _PageIndicator(
                                      count: slides.length,
                                      current: safeCurrentSlide,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      constraints.maxHeight *
                                      (isCompact ? 0.82 : 0.58),
                                ),
                                child: SingleChildScrollView(
                                  child: _WelcomeContent(
                                    slide: slides[safeCurrentSlide],
                                    compact: isCompact,
                                    largeText: isLargeText,
                                    isSubmitting: _isSubmitting,
                                    isRefreshing: asyncContent.isRefreshing,
                                    statusMessage: statusMessage,
                                    statusTone:
                                        snapshot.status ==
                                            OnboardingContentStatus
                                                .localFallback
                                        ? AfriStateBannerTone.warning
                                        : AfriStateBannerTone.neutral,
                                    whatsAppSignInAvailable:
                                        snapshot.whatsAppSignInAvailable,
                                    onSignIn: () => context.push(
                                      Uri(
                                        path: '/auth/phone',
                                        queryParameters: <String, String>{
                                          if (_deferredDestination()
                                              case final String from)
                                            'from': from,
                                        },
                                      ).toString(),
                                    ),
                                    onSkip: _continueWithoutSignIn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.imagePath,
    required this.title,
    required this.body,
    required this.semanticLabel,
  });

  final String imagePath;
  final String title;
  final String body;
  final String semanticLabel;
}

class _WelcomeBackground extends StatelessWidget {
  const _WelcomeBackground({
    super.key,
    required this.slide,
    required this.index,
    required this.count,
    required this.rightsApproved,
  });

  final _WelcomeSlide slide;
  final int index;
  final int count;
  final bool rightsApproved;

  @override
  Widget build(BuildContext context) {
    final isLargeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    return LayoutBuilder(
      builder: (context, constraints) => AfriGovernedImage(
        image: rightsApproved ? AssetImage(slide.imagePath) : null,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        semanticLabel: context.afriL10n.onboardingImageSemantic(
          slide.semanticLabel,
          index + 1,
          count,
        ),
        provenanceId: 'onboarding:${slide.imagePath}',
        rightsApproved: rightsApproved,
        fit: BoxFit.cover,
        alignment: index == 0 ? const Alignment(0.15, 0) : Alignment.topCenter,
        borderRadius: 0,
        cacheWidth:
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
        cacheHeight:
            (constraints.maxHeight * MediaQuery.devicePixelRatioOf(context))
                .ceil(),
        errorFallback: ColoredBox(
          color: ColorTokens.clubPrimary,
          child: isLargeText
              ? null
              : const Center(
                  child: Icon(
                    AfriIcons.stadium,
                    color: ColorTokens.onDark,
                    size: SizeTokens.iconDisplay,
                  ),
                ),
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.slide,
    required this.compact,
    required this.largeText,
    required this.isSubmitting,
    required this.isRefreshing,
    required this.whatsAppSignInAvailable,
    required this.onSignIn,
    required this.onSkip,
    this.statusMessage,
    this.statusTone = AfriStateBannerTone.neutral,
  });

  final _WelcomeSlide slide;
  final bool compact;
  final bool largeText;
  final bool isSubmitting;
  final bool isRefreshing;
  final bool whatsAppSignInAvailable;
  final VoidCallback onSignIn;
  final VoidCallback onSkip;
  final String? statusMessage;
  final AfriStateBannerTone statusTone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: AfriMotion.resolve(context, AfriMotion.standard),
          child: Column(
            key: ValueKey(slide.title),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slide.title,
                style: largeText
                    ? TypographyTokens.titleLarge(ColorTokens.onDark)
                    : compact
                    ? TypographyTokens.displaySmall(ColorTokens.onDark)
                    : TypographyTokens.displayLarge(ColorTokens.onDark),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                slide.body,
                style: largeText
                    ? TypographyTokens.bodyMedium(ColorTokens.onDarkSubtle)
                    : TypographyTokens.bodyLarge(ColorTokens.onDarkSubtle),
              ),
            ],
          ),
        ),
        SizedBox(
          height: compact ? SpacingTokens.spacing3 : SpacingTokens.spacing5,
        ),
        if (isRefreshing) ...[
          AfriStateBanner(
            title: l10n.onboardingRefreshingTitle,
            subtitle: l10n.onboardingRefreshingMessage,
            tone: AfriStateBannerTone.info,
            icon: AfriIcons.refresh,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
        ] else if (statusMessage case final String message) ...[
          AfriStateBanner(
            title: whatsAppSignInAvailable
                ? l10n.onboardingStatusTitle
                : l10n.onboardingWhatsAppUnavailable,
            subtitle: message,
            tone: statusTone,
            icon: whatsAppSignInAvailable
                ? AfriIcons.statusInfo
                : AfriIcons.warning,
          ),
          const SizedBox(height: SpacingTokens.spacing3),
        ],
        AfriButton(
          key: const ValueKey<String>('onboarding-whatsapp-action'),
          label: whatsAppSignInAvailable
              ? l10n.onboardingContinueWhatsApp
              : l10n.onboardingWhatsAppUnavailable,
          icon: AfriIcons.chat,
          fullWidth: true,
          enabled: whatsAppSignInAvailable && !isSubmitting,
          isLoading: isSubmitting,
          labelMaxLines: largeText ? 3 : 1,
          onTap: onSignIn,
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Center(
          child: AfriTextButton(
            key: const ValueKey<String>('onboarding-skip-action'),
            onPressed: isSubmitting ? null : onSkip,
            child: Text(
              context.afriL10n.onboardingContinueWithoutSignIn,
              style: TypographyTokens.labelLarge(ColorTokens.onDark),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingContentState extends StatelessWidget {
  const _OnboardingContentState({
    required this.clubName,
    required this.state,
    required this.isEmpty,
    required this.onRefresh,
    required this.onSignIn,
    required this.onSkip,
  });

  final String clubName;
  final AsyncValue<OnboardingContentSnapshot> state;
  final bool isEmpty;
  final VoidCallback onRefresh;
  final VoidCallback onSignIn;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final error = state.error;
    final failure = error == null
        ? null
        : OnboardingContentFailure.fromError(error);
    final stateView = isEmpty
        ? AfriStateView.empty(
            title: l10n.onboardingContentUnavailableTitle,
            message: l10n.onboardingContentUnavailableMessage,
            actionLabel: l10n.onboardingRefresh,
            onAction: onRefresh,
          )
        : failure == null
        ? AfriStateView.loading(
            title: l10n.onboardingPreparingTitle,
            message: l10n.onboardingPreparingMessage,
          )
        : switch (failure.kind) {
            OnboardingContentFailureKind.permissionDenied =>
              AfriStateView.error(
                title: l10n.onboardingAccessUnavailableTitle,
                message: l10n.onboardingAccessUnavailableMessage,
              ),
            OnboardingContentFailureKind.conflict => AfriStateView.error(
              title: l10n.onboardingChangedTitle,
              message: l10n.onboardingChangedMessage,
              actionLabel: l10n.onboardingRefresh,
              onAction: onRefresh,
            ),
            OnboardingContentFailureKind.securityTimeout => AfriStateView.error(
              title: l10n.onboardingSecurityTimeoutTitle,
              message: l10n.onboardingSecurityTimeoutMessage,
              actionLabel: l10n.onboardingRefresh,
              onAction: onRefresh,
            ),
            OnboardingContentFailureKind.unknown => AfriStateView.error(
              title: l10n.onboardingUnavailableTitle,
              message: l10n.onboardingUnavailableMessage,
              actionLabel: l10n.tryAgain,
              onAction: onRefresh,
            ),
          };

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.referenceChromeBlack,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.spacing6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AfriBrandMark(
                          label: clubName,
                          size: 56,
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusMd,
                          ),
                          semanticLabel: l10n.onboardingIdentitySemantic(
                            clubName,
                          ),
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      Expanded(child: stateView),
                      AfriButton(
                        key: const ValueKey<String>(
                          'onboarding-state-whatsapp-action',
                        ),
                        label: context.afriL10n.onboardingContinueWhatsApp,
                        icon: AfriIcons.chat,
                        onTap: onSignIn,
                      ),
                      const SizedBox(height: SpacingTokens.spacing2),
                      Center(
                        child: AfriTextButton(
                          key: const ValueKey<String>(
                            'onboarding-state-skip-action',
                          ),
                          onPressed: onSkip,
                          child: Text(
                            context.afriL10n.onboardingContinueWithoutSignIn,
                            style: TypographyTokens.labelLarge(
                              ColorTokens.onDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: AfriMotion.resolve(context, AfriMotion.standard),
          width: index == current
              ? SpacingTokens.spacing6
              : SpacingTokens.spacing2,
          height: SpacingTokens.spacing2,
          margin: const EdgeInsets.only(left: SpacingTokens.spacing2),
          decoration: BoxDecoration(
            color: index == current
                ? ColorTokens.onDark
                : ColorTokens.onDarkSubtle,
            borderRadius: ShapeTokens.buttonRadius,
          ),
        ),
      ),
    );
  }
}
