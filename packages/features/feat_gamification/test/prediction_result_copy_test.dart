import 'package:core_l10n/core_l10n.dart';
import 'package:feat_gamification/src/prediction_result_copy.dart';
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
      const Locale('en'),
      'Club context is required.',
      'Unexpected response from server.',
    ),
    (
      const Locale('en'),
      'Club context is required.',
      'Unexpected response from server.',
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
          scopedContext.localizePredictionResultMessage(
            'club_context_required',
          ),
          localeCase.$2,
        );
        expect(
          scopedContext.localizePredictionResultMessage('unexpected_response'),
          localeCase.$3,
        );
        expect(
          scopedContext.localizePredictionResultMessage(
            'server_supplied_message',
          ),
          'server_supplied_message',
        );
      },
    );
  }
}
