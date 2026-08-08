import 'package:core_l10n/core_l10n.dart';
import 'package:feat_gamification/src/game_result_copy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final localeCase in <(Locale, String, String)>[
    (
      const Locale('en'),
      'Club context is required.',
      'Unexpected response from server.',
    ),
    (
      const Locale('fr'),
      'Le contexte du club est requis.',
      'Réponse inattendue du serveur.',
    ),
    (
      const Locale('rw'),
      'Amakuru ya klabu arakenewe.',
      'Seriveri yasubije mu buryo butateganyijwe.',
    ),
  ]) {
    testWidgets(
      'localizes governed result codes in ${localeCase.$1.languageCode}',
      (tester) async {
        late BuildContext scopedContext;
        await tester.pumpWidget(
          AfriLocalizationsScope(
            locale: localeCase.$1,
            child: Builder(
              builder: (context) {
                scopedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(
          scopedContext.localizeGameResultMessage('club_context_required'),
          localeCase.$2,
        );
        expect(
          scopedContext.localizeGameResultMessage('unexpected_response'),
          localeCase.$3,
        );
        expect(
          scopedContext.localizeGameResultMessage('server_supplied_message'),
          'server_supplied_message',
        );
      },
    );
  }
}
