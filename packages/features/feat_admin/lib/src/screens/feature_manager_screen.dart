import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_providers.dart';
import '../repositories/feature_management_repository.dart';

class FeatureManagerScreen extends ConsumerStatefulWidget {
  const FeatureManagerScreen({super.key});

  @override
  ConsumerState<FeatureManagerScreen> createState() => _FeatureManagerScreenState();
}

class _FeatureManagerScreenState extends ConsumerState<FeatureManagerScreen> {
  bool _isLoading = true;
  List<ManagedPlatformFeature> _features = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFeatures());
  }

  Future<void> _loadFeatures() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final features = await ref.read(featureManagementRepositoryProvider).loadAllFeatures();
      if (mounted) {
        setState(() {
          _features = features;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _toggleFeature(String featureId, bool enabled) async {
    final success = await ref
        .read(featureManagementRepositoryProvider)
        .updateFeatureGlobalStatus(featureId, enabled);
    if (success) {
      await _loadFeatures();
    }
  }

  Future<void> _changeVisibility(String featureId, String visibility) async {
    final success = await ref
        .read(featureManagementRepositoryProvider)
        .updateFeatureVisibility(featureId, visibility);
    if (success) {
      await _loadFeatures();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(SpacingTokens.spacing6),
                        child: AfriSkeletonList(),
                      )
                    : _error != null
                        ? _buildError()
                        : RefreshIndicator(
                            onRefresh: _loadFeatures,
                            child: _buildFeatureList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(AfriIcons.chevronLeft),
          ),
          const SizedBox(width: SpacingTokens.spacing3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FEATURE MANAGER',
                  style: TypographyTokens.titleSmall().copyWith(letterSpacing: 2),
                ),
                Text(
                  '${_features.length} features registered',
                  style: TypographyTokens.bodySmall(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final grouped = <String, List<ManagedPlatformFeature>>{};
    for (final feature in _features) {
      final category = (feature.category ?? 'OTHER').toUpperCase();
      grouped.putIfAbsent(category, () => []).add(feature);
    }

    final categories = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final features = grouped[cat]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: SpacingTokens.spacing5),
            Text(
              cat,
              style: TypographyTokens.titleSmall().copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            ...features.map(_buildFeatureTile),
          ],
        );
      },
    );
  }

  Widget _buildFeatureTile(ManagedPlatformFeature feature) {
    final visibility = feature.visibilityState;
    final visIcon = switch (visibility) {
      'visible' => AfriIcons.visibility,
      'hidden' => AfriIcons.visibilityOff,
      'maintenance' => AfriIcons.statusWait,
      _ => AfriIcons.statusInfo,
    };

    final visColor = switch (visibility) {
      'visible' => ColorTokens.success,
      'hidden' => ColorTokens.error,
      'maintenance' => ColorTokens.warning,
      _ => ColorTokens.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
      child: GestureDetector(
        onTap: () => context.push('/admin/features/${feature.featureKey}'),
        child: GlassCard(
        animate: false,
        child: Row(
          children: [
            Icon(visIcon, color: visColor, size: 20),
            const SizedBox(width: SpacingTokens.spacing3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.displayName, style: TypographyTokens.bodyMedium()),
                  Text(
                    feature.featureKey,
                    style: TypographyTokens.bodySmall().copyWith(
                      color: Colors.white38,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _changeVisibility(feature.id, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'visible', child: Text('Visible')),
                const PopupMenuItem(value: 'hidden', child: Text('Hidden')),
                const PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: visColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: visColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  visibility.toUpperCase(),
                  style: TypographyTokens.labelSmall(visColor).copyWith(fontSize: 8),
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing2),
            Switch.adaptive(
              value: feature.isEnabled,
              onChanged: (v) => _toggleFeature(feature.id, v),
              activeTrackColor: ColorTokens.clubAccent,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: AfriStateView.error(
        title: 'Failed to load',
        message: _error ?? 'Unknown error',
        onAction: _loadFeatures,
      ),
    );
  }
}
