import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_recovery_screens.dart';

/// Contains URI matching and redirect failures at the parser boundary.
///
/// GoRouter's normal error builder handles failed matches, but its installed
/// parser can throw before producing that match list. Keeping containment here
/// covers initial links, nested redirects and imperative navigation together.
class RecoveringGoRouter extends GoRouter {
  RecoveringGoRouter({
    required List<RouteBase> routes,
    required String initialLocation,
    required GoRouterRedirect redirect,
    required GoRouterWidgetBuilder errorBuilder,
    Listenable? refreshListenable,
    List<NavigatorObserver> observers = const [],
  }) : this._(
         routingConfig: ValueNotifier(
           RoutingConfig(routes: routes, redirect: redirect),
         ),
         initialLocation: initialLocation,
         errorBuilder: errorBuilder,
         refreshListenable: refreshListenable,
         observers: observers,
       );

  RecoveringGoRouter._({
    required ValueNotifier<RoutingConfig> routingConfig,
    required super.initialLocation,
    required super.errorBuilder,
    super.refreshListenable,
    required super.observers,
  }) : _ownedRoutingConfig = routingConfig,
       super.routingConfig(routingConfig: routingConfig) {
    _containedParser = _RecoveringRouteInformationParser(configuration);
  }

  final ValueNotifier<RoutingConfig> _ownedRoutingConfig;
  late final GoRouteInformationParser _containedParser;

  @override
  GoRouteInformationParser get routeInformationParser => _containedParser;

  @override
  void dispose() {
    super.dispose();
    _ownedRoutingConfig.dispose();
  }
}

class _RecoveringRouteInformationParser extends GoRouteInformationParser {
  _RecoveringRouteInformationParser(RouteConfiguration configuration)
    : super(configuration: configuration, onParserException: null);

  var _failureSequence = 0;

  @override
  Future<RouteMatchList> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    try {
      // Matching decodes dynamic path parameters before any redirect callback.
      // Uri.tryParse alone does not validate those UTF8 bytes.
      routeInformation.uri.pathSegments;
      return super
          .parseRouteInformationWithDependencies(routeInformation, context)
          .then(
            (matches) {
              try {
                // Redirects may legitimately replace malformed input with a
                // safe destination. Validate their final URI before GoRouter's
                // page adapter decodes queries outside the parser boundary.
                _validateFinalUris(matches);
                return matches;
              } on FormatException catch (error) {
                return _recover(error, routeInformation);
              }
            },
            onError: (Object error, StackTrace _) =>
                _recover(error, routeInformation),
          );
    } catch (error) {
      return SynchronousFuture(_recover(error, routeInformation));
    }
  }

  void _validateFinalUris(RouteMatchList matches) {
    matches.uri.queryParametersAll;
    Uri.decodeComponent(matches.uri.fragment);
    for (final match in matches.matches) {
      _validateNestedMatch(match);
    }
  }

  void _validateNestedMatch(RouteMatchBase match) {
    if (match is ImperativeRouteMatch) {
      _validateFinalUris(match.matches);
    } else if (match is ShellRouteMatch) {
      for (final nested in match.matches) {
        _validateNestedMatch(nested);
      }
    }
  }

  RouteMatchList _recover(Object error, RouteInformation information) {
    final visualState = RouteRecoveryScreen.classifyRouterError(error);
    final reason = switch (visualState) {
      RouteRecoveryVisualState.offline => 'Route network unavailable',
      RouteRecoveryVisualState.permissionDenied => 'Route permission denied',
      RouteRecoveryVisualState.securityTimeout => 'Route check timeout',
      _ => 'Route navigation failed',
    };
    // Raw exceptions, query values, fragments and extras must not become
    // recovery state or diagnostics. The screen displays only a path category.
    final failure = RouteMatchList(
      matches: const [],
      uri: Uri(path: information.uri.path),
      pathParameters: const {},
      error: GoException(reason),
    );
    final state = information.state;
    if (state is! RouteInformationState || state.completer == null) {
      return failure;
    }

    var base = state.baseRouteMatchList!;
    ValueKey<String> pageKey = ValueKey('route-recovery-${_failureSequence++}');
    if (state.type == NavigatingType.replace ||
        state.type == NavigatingType.pushReplacement) {
      if (base.isNotEmpty) {
        final replaced = base.last;
        if (state.type == NavigatingType.replace) pageKey = replaced.pageKey;
        base = base.remove(replaced);
      }
    }
    final imperative = ImperativeRouteMatch(
      pageKey: pageKey,
      matches: failure,
      completer: state.completer!,
    );
    if (base.isEmpty) {
      return RouteMatchList(
        matches: [imperative],
        uri: failure.uri,
        pathParameters: const {},
      );
    }
    return base.push(imperative);
  }
}
