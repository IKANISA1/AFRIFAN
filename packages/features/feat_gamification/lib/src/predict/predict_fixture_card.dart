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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _team(fixture.homeTeam, fixture.homeCrest)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing2,
                    vertical: SpacingTokens.spacing5,
                  ),
                  child: Text(
                    'vs',
                    style: TypographyTokens.bodySmall(
                      ColorTokens.overviewSecondaryText,
                    ),
                  ),
                ),
                Expanded(child: _team(fixture.awayTeam, fixture.awayCrest)),
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final selection in PredictSelection.values) ...[
                  if (selection != PredictSelection.home)
                    const SizedBox(width: SpacingTokens.spacing2),
                  Expanded(
                    child: Semantics(
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
                        onPressed: enabled ? () => onPick(selection) : null,
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
                                    ? ColorTokens.primaryContainer.withValues(
                                        alpha: .16,
                                      )
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
                            : _crest(
                                selection == PredictSelection.home
                                    ? fixture.homeCrest
                                    : fixture.awayCrest,
                                24,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Semantics(
              liveRegion: true,
              child: Text(
                pending
                    ? l.predictPending
                    : fixture.selection != null
                    ? '${fixture.selectionName(fixture.selection!, l.predictDraw)} · ${switch (fixture.outcome) {
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

  Widget _team(String name, String url) => Column(
    children: [
      _crest(url, 48),
      const SizedBox(height: SpacingTokens.inlineGap),
      Text(
        name,
        textAlign: TextAlign.center,
        style: TypographyTokens.titleSmall(ColorTokens.onSurface),
      ),
    ],
  );
  Widget _crest(String url, double size) => Image.network(
    url,
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    errorBuilder: (_, __, ___) => SizedBox(
      width: size,
      height: size,
      child: Icon(
        AfriIcons.mediaUnavailable,
        size: size * .6,
        color: ColorTokens.overviewSecondaryText,
      ),
    ),
  );
}
