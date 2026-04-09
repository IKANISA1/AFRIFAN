import 'package:flutter/widgets.dart';

import 'club_config.dart';

class ClubConfigScope extends InheritedWidget {
  const ClubConfigScope({
    super.key,
    required this.config,
    required super.child,
  });

  final ClubConfig config;

  static ClubConfig? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ClubConfigScope>()
        ?.config;
  }

  static ClubConfig of(BuildContext context) {
    final config = maybeOf(context);
    assert(config != null, 'ClubConfigScope not found in context');
    return config!;
  }

  @override
  bool updateShouldNotify(ClubConfigScope oldWidget) {
    return oldWidget.config != config;
  }
}
