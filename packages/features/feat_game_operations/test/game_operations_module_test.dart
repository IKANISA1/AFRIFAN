import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('module registers owner and organizer route families', () {
    final module = GameOperationsModule();
    final paths = <String>[];

    void collect(List<RouteBase> routes, [String prefix = '']) {
      for (final route in routes.whereType<GoRoute>()) {
        final path = route.path.startsWith('/')
            ? route.path
            : '$prefix/${route.path}';
        paths.add(path);
        collect(route.routes, path);
      }
    }

    collect(module.routes);

    expect(
      paths,
      containsAll(<String>[
        '/game-operations',
        '/game-operations/sessions',
        '/game-operations/sessions/new',
        '/game-operations/sessions/:sessionId',
        '/my-tvs',
        '/my-tvs/pair',
        '/my-tvs/:displayId',
      ]),
    );
    expect(module.tabRoute, isNull);
    expect(module.routePresentationDecisions, hasLength(7));
    expect(
      module.routePresentationDecisions
          .singleWhere(
            (decision) => decision.path == '/game-operations/sessions',
          )
          .renderedStateContract,
      'controlled_organizer_inventory_surface',
    );
    expect(
      module.routePresentationDecisions
          .singleWhere(
            (decision) => decision.path == '/game-operations/sessions/new',
          )
          .renderedStateContract,
      'controlled_organizer_planner_surface',
    );
    expect(
      module.routePresentationDecisions
          .singleWhere(
            (decision) =>
                decision.path == '/game-operations/sessions/:sessionId',
          )
          .renderedStateContract,
      'controlled_organizer_live_control_surface',
    );
    expect(
      module.routePresentationDecisions
          .singleWhere((decision) => decision.path == '/game-operations')
          .renderedStateContract,
      'static_game_operations_hub_surface',
    );
    expect(
      module.routePresentationDecisions
          .singleWhere((decision) => decision.path == '/my-tvs')
          .renderedStateContract,
      'controlled_tv_inventory_surface',
    );
    expect(
      module.routePresentationDecisions
          .singleWhere((decision) => decision.path == '/my-tvs/pair')
          .renderedStateContract,
      'controlled_tv_pairing_surface',
    );
    expect(
      module.routePresentationDecisions
          .singleWhere((decision) => decision.path == '/my-tvs/:displayId')
          .renderedStateContract,
      'controlled_tv_management_surface',
    );
  });
}
