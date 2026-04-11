import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/fantasy_providers.dart';

class FantasyCreateEntryScreen extends ConsumerStatefulWidget {
  const FantasyCreateEntryScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<FantasyCreateEntryScreen> createState() =>
      _FantasyCreateEntryScreenState();
}

class _FantasyCreateEntryScreenState
    extends ConsumerState<FantasyCreateEntryScreen> {
  late final TextEditingController _teamNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _teamNameController = TextEditingController(text: 'My Fantasy XI');
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _createEntry() async {
    setState(() => _isSaving = true);
    final entryId = await ref
        .read(fantasyRepositoryProvider)
        .createEntry(
          competitionSlug: widget.slug,
          teamName: _teamNameController.text,
        );
    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    if (entryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Entry could not be created yet. Confirm login and fantasy tables.',
          ),
        ),
      );
      return;
    }

    ref.invalidate(fantasyCompetitionContextProvider(widget.slug));
    ref.invalidate(fantasyCompetitionProvider(widget.slug));
    ref.invalidate(fantasyCompetitionsProvider);
    ref.invalidate(fantasySquadBuilderProvider(widget.slug));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fantasy entry created.')));
    context.go('/fantasy/${widget.slug}/squad');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Create fantasy entry'),
      ),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name your team'.toUpperCase(),
                      style: TypographyTokens.titleLarge().copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    TextField(
                      controller: _teamNameController,
                      decoration: const InputDecoration(
                        labelText: 'Team name',
                        hintText: 'Blue Pressure XI',
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    Text(
                      'This creates the competition entry first. Squad building and player sync can continue after the entry exists.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing5),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _createEntry,
                      icon: const Icon(Icons.flag_circle_rounded),
                      label: Text(_isSaving ? 'Creating…' : 'Create entry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
