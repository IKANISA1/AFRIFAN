import 'package:core_app/bootstrap.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/feat_membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'module_registry.dart';

/// Shared entrypoint wiring: the selected module and its scoped controller are
/// supplied together. The app owns a supplied journey after bootstrap; closing
/// its provider scope disposes the controller and cancels in-memory reviews.
/// Credential and unresolved-operation journals remain in protected storage.
///
/// With no explicitly supplied journey this retains the existing membership
/// composition. Construction performs no channel, identity or payment request.
AfriClubBootstrapOptions clubBootstrapOptions(
  ClubConfig config, {
  NativeSupporterJourney? nativeSupporterJourney,
  AppStartupOptions startupOptions = const AppStartupOptions(),
  String? initialLocation,
}) {
  if (nativeSupporterJourney != null &&
      !nativeSupporterJourney.matchesClub(config.clubId)) {
    throw ArgumentError('Native membership scope does not match the club.');
  }
  return AfriClubBootstrapOptions(
    startupOptions: startupOptions,
    initialLocation: initialLocation,
    moduleBuilder: (snapshot) => AppModuleRegistry.build(
      config,
      configSnapshot: snapshot,
      nativeSupporterJourney: nativeSupporterJourney,
    ),
    providerOverrides: <Override>[
      if (nativeSupporterJourney != null)
        nativeSupporterJourneyProvider.overrideWith((ref) {
          ref.onDispose(nativeSupporterJourney.dispose);
          return nativeSupporterJourney;
        }),
    ],
    eagerProviders: <ProviderListenable<Object?>>[
      if (nativeSupporterJourney != null) nativeSupporterJourneyProvider,
    ],
    onAccountChanged: nativeSupporterJourney?.invalidate,
  );
}
