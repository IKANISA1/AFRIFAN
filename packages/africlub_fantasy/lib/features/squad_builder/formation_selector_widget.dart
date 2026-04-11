import 'package:africlub_fantasy/core/constants.dart';
import 'package:africlub_fantasy/features/shared/fantasy_ui.dart';
import 'package:flutter/material.dart';

class FormationSelectorWidget extends StatelessWidget {
  const FormationSelectorWidget({
    required this.formations,
    required this.selectedFormation,
    required this.onSelect,
    super.key,
  });

  final List<String> formations;
  final String selectedFormation;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: FantasySpacing.sm,
      runSpacing: FantasySpacing.sm,
      children: formations
          .map(
            (formation) => FantasyChipChoice(
              label: formation,
              selected: formation == selectedFormation,
              onTap: () => onSelect(formation),
            ),
          )
          .toList(growable: false),
    );
  }
}
