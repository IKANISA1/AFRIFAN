/// Centralized platform feature configuration for AFRICLUB apps.
///
/// Provides models, services, and Riverpod providers for config-driven
/// feature management. Features are fetched from Supabase at startup
/// and cached locally for resilience.
library;

// Models
export 'src/models/platform_feature_config.dart';

// Services
export 'src/services/feature_config_service.dart';

// Repositories
export 'src/repositories/feature_config_repository.dart';

// Providers
export 'src/providers/feature_config_providers.dart';

// Widgets
export 'src/widgets/feature_gate.dart';
export 'src/widgets/channel_gate.dart';
export 'src/widgets/disabled_feature_fallback.dart';
