import 'dart:async';

import 'package:core_theme/core_theme.dart';
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Partner offers are temporarily unavailable.';
      });
    }
  }

  void _openOffer(FetPartnerOffer offer) {
    if (offer.hasDeepLink) {
      unawaited(context.push(offer.deeplinkRoute!));
      return;
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: ColorTokens.surfaceContainerHigh,
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
                    label: 'Reward',
                    value: '+${offer.fetValue} FET',
                  ),
                  _OfferMetaRow(
                    label: 'Activation',
                    value: offer.activationTiming,
                  ),
                  _OfferMetaRow(
                    label: 'Verification',
                    value: _verificationLabel(offer.verificationMode),
                  ),
                  _OfferMetaRow(
                    label: 'Condition',
                    value: offer.triggerCondition,
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriButton(
                    label: 'Close',
                    onTap: () => Navigator.of(sheetContext).pop(),
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
    final maxReward = _offers.isEmpty
        ? 0
        : _offers
              .map((offer) => offer.fetValue)
              .reduce((value, element) => value > element ? value : element);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'OFFERS',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Offers unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : RefreshIndicator(
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
                      child: ClayCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OTHER WAYS TO EARN',
                              style: TypographyTokens.labelSmall(
                                ColorTokens.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              '${_wallet?.balance ?? 0} FET',
                              style: TypographyTokens.monolithFont(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: ColorTokens.clubAccent,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              'Partner campaigns, matchday activations, and club commerce offers all live here.',
                              style: TypographyTokens.bodyMedium(),
                            ),
                            const SizedBox(height: SpacingTokens.spacing4),
                            Row(
                              children: [
                                Expanded(
                                  child: _OfferStat(
                                    label: 'Active',
                                    value: '${_offers.length}',
                                  ),
                                ),
                                const SizedBox(width: SpacingTokens.spacing3),
                                Expanded(
                                  child: _OfferStat(
                                    label: 'Top reward',
                                    value: '+$maxReward',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_offers.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AfriEmptyView(
                        icon: AfriIcons.offers,
                        title: 'No partner offers live',
                        message:
                            'Offers will appear once partner campaigns are published for the active club.',
                      ),
                    )
                  else ...[
                    if (featured.isNotEmpty) ...[
                      _buildSectionHeader('Featured', featured.length),
                      _buildOfferSliver(featured),
                    ],
                    if (matchDay.isNotEmpty) ...[
                      _buildSectionHeader('Match Day', matchDay.length),
                      _buildOfferSliver(matchDay),
                    ],
                    if (alwaysOn.isNotEmpty) ...[
                      _buildSectionHeader('Always On', alwaysOn.length),
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
          SpacingTokens.spacing6,
          SpacingTokens.spacing4,
          SpacingTokens.spacing6,
          SpacingTokens.spacing3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TypographyTokens.monolithFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$count',
              style: TypographyTokens.labelSmall(
                ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferSliver(List<FetPartnerOffer> offers) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing6,
      ),
      sliver: SliverList.builder(
        itemCount: offers.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < offers.length - 1
                  ? SpacingTokens.spacing3
                  : 0,
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
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${offer.partnerEmoji ?? '🤝'} ${offer.partnerName}'.toUpperCase(),
                  style: TypographyTokens.labelSmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing2,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: ColorTokens.clubAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${offer.fetValue} FET',
                  style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(offer.title, style: TypographyTokens.titleMedium()),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(
            offer.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.activationTiming,
                  style: TypographyTokens.bodySmall(),
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              AfriButton(
                label: offer.hasDeepLink ? offer.ctaLabel : 'Details',
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
              text: '$label: ',
              style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _OfferStat extends StatelessWidget {
  const _OfferStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text(value, style: TypographyTokens.titleMedium()),
        ],
      ),
    );
  }
}

String _verificationLabel(String verificationMode) {
  return switch (verificationMode) {
    'api_confirmation' => 'Partner API confirmation',
    'renewal_confirmation' => 'Renewal confirmation',
    'referral_conversion' => 'Referral conversion',
    'receipt_scan' => 'Receipt or POS scan',
    'geo_checkin' => 'GPS or venue check-in',
    'social_share' => 'Social post verification',
    'community_savings' => 'Savings milestone confirmation',
    'ecommerce_confirmation' => 'Store purchase confirmation',
    'mobility_confirmation' => 'Ride completion confirmation',
    'event_qr' => 'Event QR validation',
    _ => 'Manual partner review',
  };
}
