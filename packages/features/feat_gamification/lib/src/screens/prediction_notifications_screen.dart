import 'package:core_theme/core_theme.dart';
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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await ref
          .read(predictionRepositoryProvider)
          .loadNotifications();
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Prediction notifications are temporarily unavailable.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Just now';
    }
    final local = value.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _openNotification(PredictionNotification notification) {
    final route = notification.route;
    final fixtureId = notification.fixtureId;

    if (route != null) {
      context.push(route);
      return;
    }
    if (fixtureId != null) {
      context.push('/fanzone/match/$fixtureId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'PREDICTION ALERTS',
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
                  title: 'Alerts unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: ColorTokens.clubAccent,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(SpacingTokens.spacing6),
                      children: const [
                        AfriEmptyView(
                          compact: true,
                          title: 'No prediction alerts yet',
                          message:
                              'Settlement and result notifications will appear here as your predictions complete.',
                          icon: AfriIcons.notifications,
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(SpacingTokens.spacing6),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: SpacingTokens.spacing3),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final canOpen =
                            notification.route != null ||
                            notification.fixtureId != null;
                        final isPositive = notification.earned > 0;
                        final accent = isPositive
                            ? ColorTokens.success
                            : ColorTokens.clubAccent;

                        return GlassCard(
                          animate: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      isPositive
                                          ? Icons.celebration_rounded
                                          : Icons.notifications_active_rounded,
                                      color: accent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: SpacingTokens.spacing3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification.title,
                                          style: TypographyTokens.titleSmall(),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(notification.createdAt),
                                          style: TypographyTokens.labelSmall(
                                            ColorTokens.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (notification.earned > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorTokens.success.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '+${notification.earned} FET',
                                        style: TypographyTokens.editorialFont(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: ColorTokens.success,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: SpacingTokens.spacing3),
                              Text(
                                notification.body,
                                style: TypographyTokens.bodyMedium(),
                              ),
                              if (canOpen) ...[
                                const SizedBox(height: SpacingTokens.spacing4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: AfriButton(
                                    label: 'OPEN',
                                    fullWidth: false,
                                    variant: AfriButtonVariant.secondary,
                                    onTap: () =>
                                        _openNotification(notification),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
