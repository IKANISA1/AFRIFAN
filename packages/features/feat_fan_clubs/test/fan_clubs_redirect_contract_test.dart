import 'package:core_router/core_router.dart';
import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'community root renders directly and cannot redirect back to Predict',
    () {
      final module = FanClubsModule();
      final root = module.routes.whereType<GoRoute>().single;
      expect(root.redirect, isNull);
      expect(root.pageBuilder, isNotNull);
      final decision = module.routePresentationDecisions.singleWhere(
        (entry) => entry.path == '/fan-clubs',
      );
      expect(decision.presentation, RoutePresentation.fullHeightSheet);
      expect(decision.targetPath, isNull);
    },
  );
}
