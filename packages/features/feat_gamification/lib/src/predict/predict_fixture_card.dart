import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'predict_models.dart';

class PredictFixtureCard extends StatelessWidget {
  const PredictFixtureCard({
    super.key,
    required this.fixture,
    required this.enabled,
    required this.pending,
    required this.onPick,
  });
  final PredictFixture fixture;
  final bool enabled;
  final bool pending;
  final void Function(PredictSelection) onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.afriL10n;
    final local = fixture.kickoffAt.toLocal();
    final material = MaterialLocalizations.of(context);
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? ColorTokens.overviewSurfaceForPath('/predict')
          : ColorTokens.surfaceContainer,
      borderRadius: ShapeTokens.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                fixture.competition,
                if (fixture.round?.isNotEmpty == true) fixture.round!,
              ].join(' · '),
              style: TypographyTokens.labelMedium(
                ColorTokens.overviewSecondaryText,
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing1),
            Text(
              '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}',
              style: TypographyTokens.bodyMedium(ColorTokens.onSurface),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            LayoutBuilder(
              builder: (context, constraints) {
                var widest = 0.0;
                for (final label in [
                  teamInitials(fixture.homeTeam),
                  l.predictDraw,
                  teamInitials(fixture.awayTeam),
                ]) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: label,
                      style: TypographyTokens.labelLarge(),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  if (painter.width > widest) widest = painter.width;
                  painter.dispose();
                }
                final stacked =
                    (constraints.maxWidth - SpacingTokens.spacing2 * 2) / 3 <
                    widest + SpacingTokens.spacing1 * 2;
                Widget arrange(Widget child) =>
                    stacked ? child : Expanded(child: child);
                return IntrinsicHeight(
                  child: Flex(
                    direction: stacked ? Axis.vertical : Axis.horizontal,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final selection in PredictSelection.values) ...[
                        if (selection != PredictSelection.home)
                          SizedBox(
                            width: stacked
                                ? SpacingTokens.spacing0
                                : SpacingTokens.spacing2,
                            height: stacked
                                ? SpacingTokens.spacing2
                                : SpacingTokens.spacing0,
                          ),
                        arrange(
                          Semantics(
                            button: true,
                            enabled: enabled,
                            selected: fixture.selection == selection,
                            label:
                                '${fixture.selectionName(selection, l.predictDraw)}, ${fixture.stakeFet} FET',
                            excludeSemantics: true,
                            onTap: enabled ? () => onPick(selection) : null,
                            child: AfriOutlinedButton(
                              key: ValueKey(
                                'predict-${fixture.id}-${selection.name}',
                              ),
                              onPressed: enabled
                                  ? () => onPick(selection)
                                  : null,
                              style:
                                  AfriOutlinedButton.styleFrom(
                                    minimumSize: const Size(
                                      SizeTokens.touchTargetMin,
                                      AfriComponentSizes.buttonHeight,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SpacingTokens.spacing1,
                                      vertical: SpacingTokens.spacing3,
                                    ),
                                    side: BorderTokens.side(
                                      color: fixture.selection == selection
                                          ? ColorTokens.primaryContainer
                                          : ColorTokens.outlineVariant,
                                      width: fixture.selection == selection
                                          ? BorderTokens.emphasis
                                          : BorderTokens.standard,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ShapeTokens.radiusMd,
                                      ),
                                    ),
                                  ).copyWith(
                                    backgroundColor: WidgetStatePropertyAll(
                                      fixture.selection == selection
                                          ? ColorTokens.primaryContainer
                                                .withValues(alpha: .16)
                                          : ColorTokens.surfaceContainerHigh,
                                    ),
                                  ),
                              child: selection == PredictSelection.draw
                                  ? Text(
                                      l.predictDraw,
                                      textAlign: TextAlign.center,
                                      style: TypographyTokens.labelLarge(
                                        ColorTokens.onSurface,
                                      ),
                                    )
                                  : Flex(
                                      direction: stacked
                                          ? Axis.horizontal
                                          : Axis.vertical,
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AfriTeamCrest(
                                          name:
                                              selection == PredictSelection.home
                                              ? fixture.homeTeam
                                              : fixture.awayTeam,
                                          crestUrl:
                                              selection == PredictSelection.home
                                              ? fixture.homeCrest
                                              : fixture.awayCrest,
                                          size: AfriComponentSizes.listIcon,
                                        ),
                                        SizedBox(
                                          width: stacked
                                              ? SpacingTokens.spacing2
                                              : SpacingTokens.spacing0,
                                          height: stacked
                                              ? SpacingTokens.spacing0
                                              : SpacingTokens.spacing2,
                                        ),
                                        Text(
                                          teamInitials(
                                            selection == PredictSelection.home
                                                ? fixture.homeTeam
                                                : fixture.awayTeam,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TypographyTokens.labelLarge(
                                            ColorTokens.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Semantics(
              liveRegion: true,
              child: Text(
                pending
                    ? l.predictPending
                    : fixture.selection != null
                    ? '${fixture.selection == PredictSelection.draw ? l.predictDraw : teamInitials(fixture.selectionName(fixture.selection!, l.predictDraw))} · ${switch (fixture.outcome) {
                        'won' => '${l.predictWon} +${fixture.payoutFet} FET',
                        'lost' => l.predictLost,
                        'refunded' => '${l.predictRefunded} +${fixture.payoutFet} FET',
                        _ => l.predictPicked,
                      }}'
                    : fixture.isOpen(DateTime.now())
                    ? '${fixture.stakeFet} FET'
                    : l.predictLocked,
                style: TypographyTokens.bodySmall(
                  ColorTokens.overviewSecondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
