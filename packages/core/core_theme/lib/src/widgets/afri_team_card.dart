import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../team_identity.dart';
import '../tokens/color_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_press_feedback.dart';

String? _networkCrest(String? value) {
  final uri = Uri.tryParse(value ?? '');
  return uri?.scheme == 'https' && uri!.host.isNotEmpty && uri.userInfo.isEmpty
      ? value
      : null;
}

/// Published artwork only. Missing media never becomes an invented club badge.
class AfriTeamCrest extends StatelessWidget {
  const AfriTeamCrest({
    super.key,
    required this.name,
    this.crestUrl,
    this.size = SizeTokens.iconXlg,
  });
  final String name;
  final String? crestUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = teamAssetFor(name, crestUrl: crestUrl)?.asset;
    final blank = SizedBox.square(dimension: size);
    final url = _networkCrest(crestUrl);
    if (asset == null && url == null) return blank;
    final path = asset ?? url!;
    final image = path.toLowerCase().endsWith('.svg')
        ? asset != null
              ? SvgPicture.asset(
                  asset,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                )
              : SvgPicture.network(
                  url!,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  placeholderBuilder: (_) => blank,
                  errorBuilder: (_, __, ___) => blank,
                )
        : asset != null
        ? Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        : Image.network(
            url!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => blank,
          );
    return Semantics(
      label: name,
      image: true,
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}

class AfriTeamCard extends StatelessWidget {
  const AfriTeamCard({
    super.key,
    required this.name,
    this.crestUrl,
    this.vertical = false,
    this.crestSize = SizeTokens.iconXlg,
  });
  final String name;
  final String? crestUrl;
  final bool vertical;
  final double crestSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final initials = teamInitials(name);
      final style = TypographyTokens.labelLarge(ColorTokens.onSurface);
      final label = TextPainter(
        text: TextSpan(text: initials, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final stack =
          vertical ||
          constraints.maxWidth <
              crestSize + SpacingTokens.spacing6 + label.width;
      label.dispose();
      final hasCrest =
          teamAssetFor(name, crestUrl: crestUrl)?.asset != null ||
          _networkCrest(crestUrl) != null;
      final children = <Widget>[
        if (hasCrest) ...[
          AfriTeamCrest(name: name, crestUrl: crestUrl, size: crestSize),
          SizedBox(
            width: stack ? SpacingTokens.spacing0 : SpacingTokens.inlineGap,
            height: stack ? SpacingTokens.spacing3 / 2 : SpacingTokens.spacing0,
          ),
        ],
        Text(initials, style: style, textAlign: TextAlign.center),
      ];
      return Semantics(
        label: name,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.spacing2),
          decoration: BoxDecoration(
            color: ColorTokens.surfaceContainer,
            borderRadius: ShapeTokens.cardRadius,
          ),
          child: stack
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
    },
  );
}

/// Match-side order is structural: first/start, then second/end.
class AfriFixtureTeams extends StatelessWidget {
  const AfriFixtureTeams({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeCrest,
    this.awayCrest,
    this.score,
    this.crestSize = SizeTokens.iconXlg,
  });
  final String homeTeam, awayTeam;
  final String? homeCrest, awayCrest, score;
  final double crestSize;

  @override
  Widget build(BuildContext context) {
    final separateScore = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final sides = Row(
      children: [
        Expanded(
          child: AfriTeamCard(
            name: homeTeam,
            crestUrl: homeCrest,
            vertical: true,
            crestSize: crestSize,
          ),
        ),
        if (score != null && !separateScore)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.spacing3,
            ),
            child: Text(score!, style: TypographyTokens.titleMedium()),
          )
        else
          const SizedBox(width: SpacingTokens.spacing3),
        Expanded(
          child: AfriTeamCard(
            name: awayTeam,
            crestUrl: awayCrest,
            vertical: true,
            crestSize: crestSize,
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sides,
        if (score != null && separateScore) ...[
          const SizedBox(height: SpacingTokens.spacing2),
          Text(score!, style: TypographyTokens.titleMedium()),
        ],
      ],
    );
  }
}

class AfriFixtureCard extends StatelessWidget {
  const AfriFixtureCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeCrest,
    this.awayCrest,
    this.score,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final String homeTeam, awayTeam;
  final String? homeCrest, awayCrest, score, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AfriPressFeedback(
    onTap: onTap,
    semanticsLabel:
        '$homeTeam, $awayTeam${score == null ? '' : ', $score'}${subtitle == null ? '' : ', $subtitle'}',
    child: Container(
      padding: const EdgeInsets.all(SpacingTokens.spacing3),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: ShapeTokens.cardRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AfriFixtureTeams(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeCrest: homeCrest,
            awayCrest: awayCrest,
            score: score,
          ),
          if (subtitle != null || trailing != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            if (subtitle != null)
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
              ),
            if (trailing != null) ...[
              const SizedBox(height: SpacingTokens.spacing3),
              trailing!,
            ],
          ],
        ],
      ),
    ),
  );
}
