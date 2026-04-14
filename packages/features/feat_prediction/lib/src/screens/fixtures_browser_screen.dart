import 'package:feat_gamification/feat_gamification.dart' as fanzone;

/// Legacy compatibility wrapper over the consolidated FANZONE fixtures browser.
class FixturesBrowserScreen extends fanzone.FixturesBrowserScreen {
  const FixturesBrowserScreen({super.key})
    : super(title: 'FIXTURES', showBackButton: false);
}
