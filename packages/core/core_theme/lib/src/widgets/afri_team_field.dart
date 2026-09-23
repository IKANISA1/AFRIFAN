import 'package:flutter/material.dart';

import '../team_identity.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'afri_bottom_sheet.dart';
import 'afri_input_field.dart';
import 'afri_press_feedback.dart';
import 'afri_team_card.dart';

/// Keeps the stored team name intact while presenting its crest and initials.
class AfriTeamField extends StatelessWidget {
  const AfriTeamField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.selectLabel = 'Select team',
    this.searchLabel = 'Search teams',
    this.useLabel = 'Use',
  });
  final String value, semanticLabel, selectLabel, searchLabel, useLabel;
  final ValueChanged<String> onChanged;

  Future<void> _choose(BuildContext context) async {
    var query = '';
    final selected = await showAfriBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final options = teamAssets
              .where(
                (team) => '${team.name} ${team.initials}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                SpacingTokens.screenPadding,
                SpacingTokens.screenPadding,
                MediaQuery.viewInsetsOf(context).bottom +
                    SpacingTokens.screenPadding,
              ),
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * .55).clamp(
                  0,
                  (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom -
                          SizeTokens.touchTargetMin)
                      .clamp(0, double.infinity),
                ),
                child: Column(
                  children: [
                    AfriTextFormField(
                      label: searchLabel,
                      onChanged: (value) =>
                          setState(() => query = value.trim()),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Expanded(
                      child: ListView.separated(
                        itemCount:
                            options.length +
                            (query.isNotEmpty &&
                                    !options.any(
                                      (team) =>
                                          team.name.toLowerCase() ==
                                          query.toLowerCase(),
                                    )
                                ? 1
                                : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: SpacingTokens.spacing2),
                        itemBuilder: (context, index) {
                          final name = index == options.length
                              ? query
                              : options[index].name;
                          return AfriPressFeedback(
                            semanticsLabel: '$useLabel $name',
                            onTap: () => Navigator.pop(context, name),
                            child: AfriTeamCard(name: name),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (context.mounted && selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => AfriPressFeedback(
    semanticsLabel: '$semanticLabel${value.isEmpty ? '' : ', $value'}',
    onTap: () => _choose(context),
    child: value.isEmpty
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SizeTokens.buttonMinHeight,
            ),
            child: Center(child: Text(selectLabel)),
          )
        : AfriTeamCard(name: value, vertical: true),
  );
}
