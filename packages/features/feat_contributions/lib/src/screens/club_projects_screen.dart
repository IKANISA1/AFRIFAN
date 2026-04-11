import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/contribution_overlays.dart';

class ClubProjectsScreen extends ConsumerStatefulWidget {
  const ClubProjectsScreen({super.key});

  @override
  ConsumerState<ClubProjectsScreen> createState() => _ClubProjectsScreenState();
}

class _ClubProjectsScreenState extends ConsumerState<ClubProjectsScreen> {
  List<Map<String, dynamic>> _projects = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final groups = await ref
          .read(clubRepositoryProvider)
          .getContributionGroups();
      final projects =
          groups
              .map(
                (group) => <String, dynamic>{
                  'id': group.id,
                  'name': group.name,
                  'description': group.description,
                  'current_total': group.currentTotal,
                  'target_amount': group.targetAmount,
                  'member_count': group.memberCount,
                  'created_at': group.createdAt.toIso8601String(),
                },
              )
              .toList(growable: false)
            ..sort((left, right) {
              final totalDiff =
                  ((right['current_total'] as num?)?.toInt() ?? 0) -
                  ((left['current_total'] as num?)?.toInt() ?? 0);
              if (totalDiff != 0) {
                return totalDiff;
              }
              final rightCreated = DateTime.tryParse(
                right['created_at']?.toString() ?? '',
              );
              final leftCreated = DateTime.tryParse(
                left['created_at']?.toString() ?? '',
              );
              if (leftCreated == null || rightCreated == null) {
                return 0;
              }
              return rightCreated.compareTo(leftCreated);
            });
      final limitedProjects = projects.take(20).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _projects = limitedProjects;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Club projects are temporarily unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'CLUB PROJECTS',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
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
                  title: 'Projects unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadProjects,
                ),
              ),
            )
          : _projects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: GlassCard(
                  animate: false,
                  child: Text(
                    'No campaigns yet. Start a new circle.',
                    style: TypographyTokens.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: SpacingTokens.spacing3,
                  ),
                  child: _ProjectCard(project: project),
                );
              },
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    );
    final title = project['name']?.toString() ?? 'Project';
    final body =
        project['description']?.toString() ??
        'Supporter-led contribution circle.';
    final currentTotal = (project['current_total'] as num?)?.toInt() ?? 0;
    final targetAmount = (project['target_amount'] as num?)?.toInt() ?? 0;
    final memberCount = (project['member_count'] as num?)?.toInt() ?? 0;
    final progress = targetAmount <= 0
        ? 0.0
        : (currentTotal / targetAmount).clamp(0.0, 1.0);
    final groupId = project['id']?.toString() ?? '';

    return GlassCard(
      animate: false,
      onTap: groupId.isEmpty
          ? null
          : () => context.push('/contribute/group/$groupId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(body, style: TypographyTokens.bodyMedium()),
          const SizedBox(height: SpacingTokens.spacing4),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: ColorTokens.surfaceContainerHighest,
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${currency.format(currentTotal)} / ${currency.format(targetAmount)}',
            style: TypographyTokens.bodySmall(),
          ),
          const SizedBox(height: SpacingTokens.spacing1),
          Text('$memberCount supporters', style: TypographyTokens.bodySmall()),
          const SizedBox(height: SpacingTokens.spacing4),
          ClaymorphicButton(
            label: 'CONTRIBUTE',
            width: double.infinity,
            onPressed: () => showMomoAmountEntrySheet(context, title: title),
          ),
        ],
      ),
    );
  }
}
