/// Core Observability — sub-barrel for monitoring, analytics, and diagnostics.
///
/// This groups the observability services logically within core_network.
/// When a physical package split is attempted in the future, move these files
/// to `packages/core/core_observability` and update imports from this barrel.
///
/// Services included:
/// - CrashlyticsService: crash/error reporting
/// - FirebaseAnalyticsService: structured analytics events
/// - OperationalHealthService: platform health monitoring
/// - OfflineEventQueue: queued telemetry for offline-first delivery

export 'src/crashlytics_service.dart';
export 'src/firebase_analytics_service.dart';
export 'src/offline_event_queue.dart';
export 'src/operational_health_service.dart';
