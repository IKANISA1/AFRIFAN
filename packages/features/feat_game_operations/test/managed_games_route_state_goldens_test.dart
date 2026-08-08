import 'managed_games_route_state_golden_support.dart';

void main() {
  for (final state in <String>[
    'loading',
    'empty',
    'error',
    'offline',
    'permission_denied',
    'disabled',
    'focused',
    'pressed',
    'large_text',
    'reduced_motion',
    'dark',
    'light',
    'syncing',
    'security_timeout',
  ]) {
    registerManagedGamesRouteStateGolden(state);
  }
}
