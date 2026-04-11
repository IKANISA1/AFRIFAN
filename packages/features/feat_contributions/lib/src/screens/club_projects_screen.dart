import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final response = await ref
          .read(supabaseClientProvider)
          .from('contribution_groups')
          .select()
          .eq('is_closed', false)
          .order('current_total', ascending: false)
          .order('created_at', ascending: false)
          .limit(20);

      if (!mounted) return;
      setState(() {
        _projects = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
            'FRw $currentTotal / FRw $targetAmount',
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
