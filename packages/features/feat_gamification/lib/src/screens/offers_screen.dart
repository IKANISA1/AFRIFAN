import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  FetWalletSummary? _wallet;
  List<FetPartnerOffer> _offers = const <FetPartnerOffer>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        ref.read(fetRepositoryProvider).loadWallet(),
        ref.read(fetRepositoryProvider).loadPartnerOffers(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _wallet = results[0] as FetWalletSummary?;
        _offers = results[1]! as List<FetPartnerOffer>;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'OffersScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameOffersTemporarilyUnavailable;
      });
    }
  }

  void _openOffer(FetPartnerOffer offer) {
    if (offer.hasDeepLink) {
      unawaited(context.push(offer.deeplinkRoute!));
      return;
    }
    unawaited(
      showAfriBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing2,
                SpacingTokens.spacing6,
                SpacingTokens.spacing6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.partnerName.toUpperCase(),
                    style: TypographyTokens.labelSmall(
                      ColorTokens.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing2),
                  Text(offer.title, style: TypographyTokens.headlineSmall()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(offer.description, style: TypographyTokens.bodyMedium()),
                  const SizedBox(height: SpacingTokens.spacing4),
                  _OfferMetaRow(
                    label: sheetContext.afriL10n.gameReward,
                    value: sheetContext.afriL10n.gamePoints(offer.fetValue),
                  ),
                  _OfferMetaRow(
                    label: sheetContext.afriL10n.gameActivation,
                    value: offer.activationTiming,
                  ),
                  _OfferMetaRow(
                    label: sheetContext.afriL10n.gameVerification,
                    value: _verificationLabel(
                      sheetContext,
                      offer.verificationMode,
                    ),
                  ),
                  _OfferMetaRow(
                    label: sheetContext.afriL10n.gameCondition,
                    value: offer.triggerCondition,
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriButton(
                    label: sheetContext.afriL10n.gameClose,
                    onTap: () => sheetContext.pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = _offers
        .where((offer) => offer.isFeatured)
        .toList(growable: false);
    final matchDay = _offers
        .where((offer) => !offer.isFeatured && offer.isMatchDay)
        .toList(growable: false);
    final alwaysOn = _offers
        .where((offer) => !offer.isFeatured && !offer.isMatchDay)
        .toList(growable: false);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameOffersTitle,
          style: TypographyTokens.headlineSmall(),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: false,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: context.afriL10n.gameOffersUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Header card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SpacingTokens.spacing6,
                        SpacingTokens.spacing6,
                        SpacingTokens.spacing6,
                        SpacingTokens.spacing5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AfriSectionHeader(
                            title: context.afriL10n.gameWaysToEarn,
                            subtitle:
                                context.afriL10n.gameWaysToEarnDescription,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: SpacingTokens.spacing4),
                          Row(
                            children: [
                              Expanded(
                                child: AfriMetricTile(
                                  label: context.afriL10n.gameBalance,
                                  value: context.afriL10n.gamePointBalance(
                                    _wallet?.balance ?? 0,
                                  ),
                                  accentColor: ColorTokens.clubAccent,
                                ),
                              ),
                              const SizedBox(width: SpacingTokens.spacing3),
                              Expanded(
                                child: AfriMetricTile(
                                  label: context.afriL10n.gameAvailable,
                                  value: _offers.length.toString(),
                                  meta: context.afriL10n.gameActiveOffers(
                                    _offers.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_offers.isEmpty)
                    const SliverToBoxAdapter(child: SizedBox.shrink())
                  else ...[
                    if (featured.isNotEmpty) ...[
                      _buildSectionHeader(
                        context.afriL10n.gameFeatured,
                        featured.length,
                      ),
                      _buildOfferSliver(featured),
                    ],
                    if (matchDay.isNotEmpty) ...[
                      _buildSectionHeader(
                        context.afriL10n.gameMatchDay,
                        matchDay.length,
                      ),
                      _buildOfferSliver(matchDay),
                    ],
                    if (alwaysOn.isNotEmpty) ...[
                      _buildSectionHeader(
                        context.afriL10n.gameAlwaysOn,
                        alwaysOn.length,
                      ),
                      _buildOfferSliver(alwaysOn),
                    ],
                  ],
                  // Bottom padding
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: SpacingTokens.spacing6),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.spacing0,
          SpacingTokens.spacing4,
          SpacingTokens.spacing0,
          SpacingTokens.spacing3,
        ),
        child: AfriSectionHeader(
          title: title,
          trailing: Text(
            count.toString(),
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferSliver(List<FetPartnerOffer> offers) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      sliver: SliverList.builder(
        itemCount: offers.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < offers.length - 1 ? SpacingTokens.spacing3 : 0,
            ),
            child: _OfferCard(
              offer: offers[index],
              onTap: () => _openOffer(offers[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});

  final FetPartnerOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.partnerName,
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ),
              AfriStatusChip(
                label: context.afriL10n.gamePoints(offer.fetValue),
                tone: AfriStatusTone.live,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Text(offer.title, style: TypographyTokens.titleMedium()),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            offer.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.activationTiming,
                  style: TypographyTokens.labelSmall(),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              AfriButton(
                label: offer.hasDeepLink
                    ? offer.ctaLabel
                    : context.afriL10n.gameDetails,
                onTap: onTap,
                fullWidth: false,
                variant: offer.hasDeepLink
                    ? AfriButtonVariant.primary
                    : AfriButtonVariant.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferMetaRow extends StatelessWidget {
  const _OfferMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: RichText(
        text: TextSpan(
          style: TypographyTokens.bodySmall(),
          children: [
            TextSpan(
              text: label,
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
            const TextSpan(text: ': '),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

String _verificationLabel(BuildContext context, String verificationMode) {
  return switch (verificationMode) {
    'api_confirmation' => context.afriL10n.gameVerificationApi,
    'renewal_confirmation' => context.afriL10n.gameVerificationRenewal,
    'referral_conversion' => context.afriL10n.gameVerificationReferral,
    'receipt_scan' => context.afriL10n.gameVerificationReceipt,
    'geo_checkin' => context.afriL10n.gameVerificationGeo,
    'social_share' => context.afriL10n.gameVerificationSocial,
    'community_savings' => context.afriL10n.gameVerificationSavings,
    'ecommerce_confirmation' => context.afriL10n.gameVerificationEcommerce,
    'mobility_confirmation' => context.afriL10n.gameVerificationMobility,
    'event_qr' => context.afriL10n.gameVerificationEventQr,
    _ => context.afriL10n.gameVerificationManual,
  };
}
