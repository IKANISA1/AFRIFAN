import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';

/// Home feature module — the main tab with CMS hero, match, quick actions.
class HomeModule extends FeatureModule {
  @override
  String get featureKey => 'home';

  @override
  TabRoute get tabRoute => TabRoute(
    path: '/home',
    label: 'HOME',
    icon: Icons.stadium_outlined,
    activeIcon: Icons.stadium,
    builder: (context, state) => const HomeScreen(),
  );

  @override
  List<RouteBase> get routes => [];
}
