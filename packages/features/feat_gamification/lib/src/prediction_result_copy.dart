import 'package:core_l10n/core_l10n.dart';
import 'package:flutter/widgets.dart';

extension PredictionResultCopyContext on BuildContext {
  String localizePredictionResultMessage(String message) {
    return switch (message) {
      'club_context_required' => afriL10n.gameClubContextRequired,
      'unexpected_response' => afriL10n.gameUnexpectedResponse,
      _ => message,
    };
  }
}
