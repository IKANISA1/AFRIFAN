import 'dart:ui';

import 'package:africlub_fantasy/core/constants.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class FantasyScaffold extends StatelessWidget {
  const FantasyScaffold({
    required this.child,
    this.title,
    this.actions,
    this.showBackButton = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.appBarBottom,
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBarBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FantasyColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: showBackButton
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: FantasyColors.textPrimary,
              )
            : null,
        title: title == null
            ? null
            : Text(
                title!,
                style: FantasyTypography.h2.copyWith(
                  color: FantasyColors.textPrimary,
                ),
              ),
        actions: actions,
        bottom: appBarBottom,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF111111),
              FantasyColors.background,
              Color(0xFF151515),
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

class FantasyGlassCard extends StatelessWidget {
  const FantasyGlassCard({
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(FantasySpacing.md),
      borderColor: FantasyColors.border.withValues(alpha: 0.8),
      onTap: onTap,
      child: child,
    );
  }
}

class FantasySectionHeader extends StatelessWidget {
  const FantasySectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: FantasyTypography.h3.copyWith(
                  color: FantasyColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: FantasySpacing.xs),
                Text(
                  subtitle!,
                  style: FantasyTypography.caption.copyWith(
                    color: FantasyColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class FantasyStatusBadge extends StatelessWidget {
  const FantasyStatusBadge({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label.toUpperCase(),
        style: FantasyTypography.label.copyWith(color: color),
      ),
    );
  }
}

class FantasyOfflineBanner extends StatelessWidget {
  const FantasyOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: FantasySpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: FantasySpacing.md,
        vertical: FantasySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: FantasyColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: FantasyColors.warningAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.wifi_off_rounded,
            color: FantasyColors.warningAmber,
            size: 18,
          ),
          const SizedBox(width: FantasySpacing.sm),
          Expanded(
            child: Text(
              'Offline mode. Showing the last known squad snapshot.',
              style: FantasyTypography.caption.copyWith(
                color: FantasyColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FantasyStateCard extends StatelessWidget {
  const FantasyStateCard.loading({this.onRetry, super.key})
    : title = 'Loading',
      message = 'Please wait while fantasy data loads.',
      tone = AfriStateTone.loading;

  const FantasyStateCard.empty({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  }) : tone = AfriStateTone.empty;

  const FantasyStateCard.error({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  }) : tone = AfriStateTone.error;

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final AfriStateTone tone;

  @override
  Widget build(BuildContext context) {
    switch (tone) {
      case AfriStateTone.loading:
        return AfriStateView.loading(compact: false);
      case AfriStateTone.empty:
        return AfriStateView.empty(
          title: title,
          message: message,
          actionLabel: onRetry == null ? null : 'Retry',
          onAction: onRetry,
        );
      case AfriStateTone.error:
        return AfriStateView.error(
          title: title,
          message: message,
          actionLabel: onRetry == null ? null : 'Retry',
          onAction: onRetry,
        );
      case AfriStateTone.offline:
      case AfriStateTone.success:
        return AfriStateView(
          tone: tone,
          title: title,
          message: message,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class FantasySkeletonCard extends StatelessWidget {
  const FantasySkeletonCard({this.height = 128, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return FantasyGlassCard(
      child: SizedBox(height: height, child: const AfriSkeleton.card()),
    );
  }
}

class FantasyChipChoice extends StatelessWidget {
  const FantasyChipChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? FantasyColors.textPrimary.withValues(alpha: 0.08)
              : FantasyColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? FantasyColors.textPrimary.withValues(alpha: 0.25)
                : FantasyColors.border,
          ),
        ),
        child: Text(
          label,
          style: FantasyTypography.caption.copyWith(
            color: selected
                ? FantasyColors.textPrimary
                : FantasyColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class FantasySearchField extends StatelessWidget {
  const FantasySearchField({
    required this.controller,
    this.hintText = 'Search',
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: FantasyTypography.body.copyWith(
            color: FantasyColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: FantasyTypography.body.copyWith(
              color: FantasyColors.textMuted,
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            prefixIconColor: FantasyColors.textSecondary,
            filled: true,
            fillColor: FantasyColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: FantasyColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: FantasyColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: FantasyColors.successGreen),
            ),
          ),
        ),
      ),
    );
  }
}
