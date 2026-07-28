// Core Network — Supabase client, config, and services.
//
// Observability services (Crashlytics, Analytics, OperationalHealth,
// OfflineEventQueue) are also exported via core_observability.dart for
// consumers that only need monitoring/diagnostics.

export 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

export 'src/afri_governed_cached_image.dart';
export 'src/afri_image_cache_manager.dart';
export 'src/app_check_service.dart';
export 'src/app_config_repository.dart';
export 'src/club_scope.dart';
export 'src/connectivity_service.dart';
export 'src/country_repository.dart';
export 'src/crashlytics_service.dart';
export 'src/firebase_analytics_service.dart';
export 'src/firebase_bootstrap_service.dart';
export 'src/firebase_observability_config.dart';
export 'src/hive_cache_service.dart';
export 'src/hive_encryption_service.dart';
export 'src/offline_banner.dart';
export 'src/offline_event_queue.dart';
export 'src/offline_recovery_controller.dart';
export 'src/operational_health_service.dart';
export 'src/privacy_safe_analytics.dart';
export 'src/push_notification_service.dart';
export 'src/realtime_service.dart';
export 'src/safe_rpc.dart';
export 'src/sms_ingestion_repository.dart';
export 'src/supabase_client_factory.dart';
export 'src/supabase_providers.dart';
