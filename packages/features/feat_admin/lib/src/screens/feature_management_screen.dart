import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_feature_config/core_feature_config.dart';

import '../admin_providers.dart';

class FeatureManagementScreen extends ConsumerStatefulWidget {
  const FeatureManagementScreen({super.key});

  @override
  ConsumerState<FeatureManagementScreen> createState() => _FeatureManagementScreenState();
}

class _FeatureManagementScreenState extends ConsumerState<FeatureManagementScreen> {
  bool _loading = true;
  List<PlatformFeature> _features = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final features = await ref.read(featureManagementRepositoryProvider).loadAllFeatures();
      if (mounted) {
        setState(() {
          _features = features;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load features: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleGlobal(PlatformFeature feature, bool value) async {
    final success = await ref.read(featureManagementRepositoryProvider).updateFeatureGlobalStatus(feature.featureKey, value);
    if (success) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PLATFORM FEATURES',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(AfriIcons.refresh),
          ),
          const SizedBox(width: SpacingTokens.spacing2),
        ],
      ),
      body: _loading
          ? const Center(child: AfriLoadingIndicator())
          : _error != null
              ? AfriStateView.error(
                  title: 'Error',
                  message: _error!,
                  onAction: _loadData,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                  itemCount: _features.length,
                  separatorBuilder: (_, __) => const SizedBox(height: SpacingTokens.spacing4),
                  itemBuilder: (context, index) {
                    final feature = _features[index];
                    return _FeatureConfigCard(
                      feature: feature,
                      onToggleGlobal: (val) => _toggleGlobal(feature, val),
                    );
                  },
                ),
    );
  }
}

class _FeatureConfigCard extends StatelessWidget {
  const _FeatureConfigCard({
    required this.feature,
    required this.onToggleGlobal,
  });

  final PlatformFeature feature;
  final ValueChanged<bool> onToggleGlobal;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.displayName.toUpperCase(),
                      style: TypographyTokens.titleMedium(),
                    ),
                    Text(
                      (feature.category ?? 'OTHER').toUpperCase(),
                      style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: feature.isEnabled,
                onChanged: onToggleGlobal,
                activeTrackColor: ColorTokens.clubAccent,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          if (feature.description != null)
            Text(
              feature.description!,
              style: TypographyTokens.bodySmall(),
            ),
          const SizedBox(height: SpacingTokens.spacing4),
          const Divider(height: 1),
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            children: [
              _ChannelBadge(
                label: 'MOBILE',
                enabled: feature.channel?.isEnabled ?? true,
                nav: feature.channel?.showInNavigation ?? false,
                home: feature.channel?.showOnHome ?? false,
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              _ChannelBadge(
                label: 'WEB',
                enabled: true, // Placeholder
                nav: true,
                home: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelBadge extends StatelessWidget {
  const _ChannelBadge({
    required this.label,
    required this.enabled,
    required this.nav,
    required this.home,
  });

  final String label;
  final bool enabled;
  final bool nav;
  final bool home;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? ColorTokens.success : ColorTokens.onSurfaceVariant;
    
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: BorderTokens.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TypographyTokens.editorialFont(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _TinyIcon(icon: AfriIcons.grid, active: home),
              const SizedBox(width: 4),
              _TinyIcon(icon: Icons.navigation_rounded, active: nav),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon({required this.icon, required this.active});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 10,
      color: active ? ColorTokens.clubAccent : ColorTokens.onSurfaceVariant.withValues(alpha: 0.3),
    );
  }
}
