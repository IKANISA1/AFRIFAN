import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fanzone_models.dart';
import '../prediction_providers.dart';

class PredictionNotificationsScreen extends ConsumerStatefulWidget {
  const PredictionNotificationsScreen({super.key});

  @override
  ConsumerState<PredictionNotificationsScreen> createState() =>
      _PredictionNotificationsScreenState();
}

class _PredictionNotificationsScreenState
    extends ConsumerState<PredictionNotificationsScreen> {
  List<PredictionNotification> _notifications =
      const <PredictionNotification>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await ref.read(
        predictionNotificationsLoaderProvider,
      )();
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'PredictionNotificationsScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Prediction notifications are temporarily unavailable.';
        _isLoading = false;
      });
    }
  }

  void _openNotification(PredictionNotification notification) {
    final route = notification.route;
    final fixtureId = notification.fixtureId;

    if (route != null) {
      unawaited(context.push(route));
      return;
    }
    if (fixtureId != null) {
      unawaited(context.push('/fanzone/match/$fixtureId'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          'PREDICTION ALERTS',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
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
                  title: 'Alerts unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: PredictionNotificationsList(
                notifications: _notifications,
                onOpenNotification: _openNotification,
              ),
            ),
    );
  }
}

class PredictionNotificationsList extends StatelessWidget {
  const PredictionNotificationsList({
    super.key,
    required this.notifications,
    this.onOpenNotification,
  });

  final List<PredictionNotification> notifications;
  final void Function(PredictionNotification notification)? onOpenNotification;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey<String>('prediction-notifications-empty'),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      itemCount: notifications.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: SpacingTokens.spacing3),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _PredictionNotificationCard(
          notification: notification,
          onOpen: onOpenNotification == null
              ? null
              : () => onOpenNotification!(notification),
        );
      },
    );
  }
}

class _PredictionNotificationCard extends StatelessWidget {
  const _PredictionNotificationCard({required this.notification, this.onOpen});

  final PredictionNotification notification;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final openNotification = onOpen;
    final canOpen = openNotification != null;
    final isPositive = notification.earned > 0;
    final accent = isPositive ? ColorTokens.success : ColorTokens.clubAccent;
    final dateLabel = _formatPredictionNotificationDate(notification.createdAt);
    final rewardLabel = isPositive
        ? ', reward ${notification.earned} points'
        : '';

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            label:
                'Prediction alert, ${notification.title}, '
                '${notification.body}, $dateLabel$rewardLabel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: SpacingTokens.spacing10,
                      height: SpacingTokens.spacing10,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          ShapeTokens.radiusMd,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isPositive
                            ? AfriIcons.gift
                            : AfriIcons.notificationsActive,
                        color: accent,
                        size: SpacingTokens.spacing5,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: TypographyTokens.titleSmall(),
                          ),
                          const SizedBox(height: SpacingTokens.spacing1 / 2),
                          Text(
                            dateLabel,
                            style: TypographyTokens.labelSmall(
                              ColorTokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPositive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing3,
                          vertical: SpacingTokens.spacing1,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTokens.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusFull,
                          ),
                        ),
                        child: Text(
                          '+${notification.earned} pts',
                          style:
                              TypographyTokens.labelMedium(
                                ColorTokens.success,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Text(notification.body, style: TypographyTokens.bodyMedium()),
              ],
            ),
          ),
          if (canOpen) ...[
            const SizedBox(height: SpacingTokens.spacing4),
            Align(
              alignment: Alignment.centerLeft,
              child: AfriButton(
                label: 'OPEN',
                fullWidth: false,
                variant: AfriButtonVariant.secondary,
                onTap: openNotification,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatPredictionNotificationDate(DateTime? value) {
  if (value == null) {
    return 'Just now';
  }
  final local = value.toLocal();
  return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
