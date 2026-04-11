import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/ai_advisor/advice_card_widget.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:africlub_fantasy/providers/ai_providers.dart';
import 'package:africlub_fantasy/providers/competition_providers.dart';
import 'package:africlub_fantasy/providers/squad_providers.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _AdvisorMode { advice, debrief }

class AIAdvisorSheet extends ConsumerStatefulWidget {
  const AIAdvisorSheet({required this.entryId, this.slug, super.key});

  const AIAdvisorSheet.standalone({required this.slug, super.key})
    : entryId = '';

  final String entryId;
  final String? slug;

  @override
  ConsumerState<AIAdvisorSheet> createState() => _AIAdvisorSheetState();
}

class _AIAdvisorSheetState extends ConsumerState<AIAdvisorSheet> {
  final TextEditingController _controller = TextEditingController();
  _AdvisorMode _mode = _AdvisorMode.advice;

  static const List<String> _advicePrompts = <String>[
    'Best transfer this week?',
    'Captain pick?',
    'Should I play a chip?',
    'Biggest risk in my squad?',
  ];

  static const List<String> _debriefPrompts = <String>[
    'Give me a post-gameweek debrief.',
    'What cost me points?',
    'Who overperformed in my squad?',
    'What should I change next week?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adviceState = ref.watch(aiAdviceControllerProvider);

    return FantasyScaffold(
      title: 'AI Advisor',
      child: _buildResolvedBody(context, adviceState),
    );
  }

  Widget _buildResolvedBody(
    BuildContext context,
    AsyncValue<dynamic> adviceState,
  ) {
    if (widget.entryId.isNotEmpty) {
      return _buildBody(context, widget.entryId, adviceState);
    }

    final slug = widget.slug;
    if (slug == null || slug.isEmpty) {
      return const Center(
        child: FantasyStateCard.empty(
          title: 'No fantasy entry found',
          message: 'Build a squad first to unlock AI advice.',
        ),
      );
    }

    final competitionAsync = ref.watch(competitionProvider(slug));
    return competitionAsync.when(
      data: (competition) {
        final entryAsync = ref.watch(myEntryProvider(competition.id));
        return entryAsync.when(
          data: (entry) {
            if (entry == null) {
              return const Center(
                child: FantasyStateCard.empty(
                  title: 'No fantasy entry found',
                  message: 'Build a squad first to unlock AI advice.',
                ),
              );
            }
            return _buildBody(context, entry.id, adviceState);
          },
          loading: () => const Center(child: FantasyStateCard.loading()),
          error: (error, _) => Center(
            child: FantasyStateCard.error(
              title: 'Entry failed to load',
              message: error.toString(),
            ),
          ),
        );
      },
      loading: () => const Center(child: FantasyStateCard.loading()),
      error: (error, _) => Center(
        child: FantasyStateCard.error(
          title: 'Competition failed to load',
          message: error.toString(),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String entryId,
    AsyncValue<dynamic> adviceState,
  ) {
    final prompts = _mode == _AdvisorMode.debrief
        ? _debriefPrompts
        : _advicePrompts;

    return ListView(
      padding: const EdgeInsets.all(FantasySpacing.md),
      children: <Widget>[
        Row(
          children: <Widget>[
            const _GeminiMark(),
            const SizedBox(width: FantasySpacing.sm),
            Text(
              _mode == _AdvisorMode.debrief ? 'AI Debrief' : 'AI Advisor',
              style: FantasyTypography.h2.copyWith(
                color: FantasyColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: FantasySpacing.md),
        Wrap(
          spacing: FantasySpacing.sm,
          runSpacing: FantasySpacing.sm,
          children: <Widget>[
            FantasyChipChoice(
              label: 'Advice',
              selected: _mode == _AdvisorMode.advice,
              onTap: () => setState(() => _mode = _AdvisorMode.advice),
            ),
            FantasyChipChoice(
              label: 'Debrief',
              selected: _mode == _AdvisorMode.debrief,
              onTap: () => setState(() => _mode = _AdvisorMode.debrief),
            ),
          ],
        ),
        const SizedBox(height: FantasySpacing.md),
        Wrap(
          spacing: FantasySpacing.sm,
          runSpacing: FantasySpacing.sm,
          children: prompts
              .map(
                (prompt) => FantasyChipChoice(
                  label: prompt,
                  selected: _controller.text == prompt,
                  onTap: () => setState(() => _controller.text = prompt),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: FantasySpacing.md),
        FantasySearchField(
          controller: _controller,
          hintText: _mode == _AdvisorMode.debrief
              ? 'Ask for a post-gameweek breakdown'
              : 'Ask a custom fantasy question',
        ),
        const SizedBox(height: FantasySpacing.md),
        AfriButton(
          label: _mode == _AdvisorMode.debrief ? 'Generate debrief' : 'Ask',
          onTap: () {
            ref
                .read(aiAdviceControllerProvider.notifier)
                .ask(
                  entryId: entryId,
                  question: _controller.text.trim(),
                  debrief: _mode == _AdvisorMode.debrief,
                );
          },
          variant: AfriButtonVariant.accent,
        ),
        const SizedBox(height: FantasySpacing.lg),
        adviceState.when(
          data: (advice) => advice == null
              ? FantasyStateCard.empty(
                  title: _mode == _AdvisorMode.debrief
                      ? 'No debrief yet'
                      : 'No advice yet',
                  message: _mode == _AdvisorMode.debrief
                      ? 'Generate a debrief to review your latest gameweek.'
                      : 'Ask a question to get a tactical recommendation.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      advice.question,
                      style: FantasyTypography.caption.copyWith(
                        color: FantasyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: FantasySpacing.sm),
                    AdviceCardWidget(
                      advice: advice.advice,
                      onCopy: () async {
                        await Clipboard.setData(
                          ClipboardData(text: advice.advice),
                        );
                        if (context.mounted) {
                          AfriToast.success(context, 'Advice copied.');
                        }
                      },
                    ),
                  ],
                ),
          loading: () => const _TypingIndicator(),
          error: (error, _) => FantasyStateCard.error(
            title: 'Advisor unavailable',
            message: error.toString(),
          ),
        ),
      ],
    );
  }
}

class _GeminiMark extends StatelessWidget {
  const _GeminiMark();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.78,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: FantasyColors.textPrimary),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = (_controller.value * 3).floor() % 3;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            3,
            (index) => Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: index == active
                    ? FantasyColors.textPrimary
                    : FantasyColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
