import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_contributions/src/widgets/group_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final localeCase in <_LocaleCase>[
    const _LocaleCase(
      locale: Locale('en'),
      contributors: '12 contributors',
      progress: '40% of goal',
    ),
    const _LocaleCase(
      locale: Locale('zz'),
      contributors: '12 contributors',
      progress: '40% of goal',
    ),
  ]) {
    testWidgets(
      'initiative card renders the ${localeCase.locale.languageCode} journey',
      (tester) async {
        await tester.pumpWidget(
          _LocalizedContributionSurface(
            locale: localeCase.locale,
            child: GroupCard(
              group: const <String, dynamic>{
                'name': 'Away Day Support',
                'target_amount': 100000,
                'current_total': 40000,
                'member_count': 12,
              },
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(localeCase.contributors), findsOneWidget);
        expect(find.text(localeCase.progress), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _LocalizedContributionSurface extends StatelessWidget {
  const _LocalizedContributionSurface({
    required this.locale,
    required this.child,
  });

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = ClubConfig.fallback();
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const <Locale>[Locale('en')],
      localizationsDelegates: AfriLocalizations.localizationsDelegates,
      theme: ClubTheme.from(config),
      builder: (context, appChild) => AfriLocalizationsScope(
        locale: locale,
        child: appChild ?? const SizedBox.shrink(),
      ),
      home: ClubConfigScope(
        config: config,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing4),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LocaleCase {
  const _LocaleCase({
    required this.locale,
    required this.contributors,
    required this.progress,
  });

  final Locale locale;
  final String contributors;
  final String progress;
}
