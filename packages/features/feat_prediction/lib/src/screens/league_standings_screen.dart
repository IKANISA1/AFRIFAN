import 'package:feat_gamification/feat_gamification.dart' as fanzone;

/// Legacy compatibility wrapper over the consolidated FANZONE league standings.
class LeagueStandingsScreen extends fanzone.LeagueStandingsScreen {
  const LeagueStandingsScreen({super.key, required super.competitionSlug});
}
