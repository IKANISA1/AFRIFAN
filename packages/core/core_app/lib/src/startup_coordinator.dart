import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_sms_ledger/feat_sms_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppStartupOptions {
  const AppStartupOptions({
    this.configureDeviceChrome = true,
    this.initializePersistence = true,
    this.initializeBackend = true,
    this.initializeSmsAutoread = true,
    this.firebaseOptions,
  });

  const AppStartupOptions.integrationTest()
    : configureDeviceChrome = false,
      initializePersistence = false,
      initializeBackend = false,
      initializeSmsAutoread = false,
      firebaseOptions = null;

  final bool configureDeviceChrome;
  final bool initializePersistence;
  final bool initializeBackend;
  final bool initializeSmsAutoread;
  final FirebaseOptions? firebaseOptions;
}

/// Centralizes startup side effects so app bootstrap stays declarative.
class AppStartupCoordinator {
  AppStartupCoordinator({this.options = const AppStartupOptions()});

  final AppStartupOptions options;

  Future<void> initialize(ClubConfig config) async {
    ColorTokens.init(config.colors);

    if (options.configureDeviceChrome) {
      await _configureDeviceChrome();
    }
    if (options.initializePersistence) {
      await _initializePersistence();
    }
    if (options.initializeBackend) {
      await _initializeBackend(config);
    }
    if (options.initializeSmsAutoread) {
      _initializeSmsAutoread(config);
    }
  }

  Future<void> _configureDeviceChrome() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ColorTokens.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _initializePersistence() async {
    await Hive.initFlutter();
  }

  Future<void> _initializeBackend(ClubConfig config) async {
    await FirebaseBootstrapService.initialize(options: options.firebaseOptions);
    await AppCheckService.initialize();

    await SupabaseClientFactory.initialize(
      supabaseUrl: config.supabaseUrl,
      supabaseAnonKey: config.supabaseAnonKey,
    );

    await PushNotificationService.initialize(clubId: config.clubId);

    final countryRepo = CountryRepository(client: SupabaseClientFactory.client);
    await countryRepo.loadAndInject();
  }

  void _initializeSmsAutoread(ClubConfig config) {
    try {
      if (!EnvConfig.enableAndroidMomoSmsAutoread) {
        debugPrint('[Bootstrap] SMS autoread disabled for this build.');
        return;
      }

      final client = SupabaseClientFactory.client;
      final smsService = MomoSmsAutoreadService(
        client: client,
        appAccessService: AppAccessService(openBox: openHiveBox<bool>),
        countryCode: config.countryCode,
      );
      final reconciliationService = LedgerReconciliationService(client: client);

      client.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.tokenRefreshed) {
          smsService.refresh();
          _runReconciliation(reconciliationService);
        } else if (event.event == AuthChangeEvent.signedOut) {
          smsService.stop(resetPermissionPromptState: true);
        }
      });

      if (client.auth.currentSession != null) {
        smsService.refresh();
        _runReconciliation(reconciliationService);
      }
    } catch (error) {
      debugPrint('[Bootstrap] SMS autoread init failed (non-fatal): $error');
    }
  }

  void _runReconciliation(LedgerReconciliationService service) {
    Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        final count = await service.reconcilePending();
        if (count > 0) {
          debugPrint('[Bootstrap] Reconciled $count contributions.');
        }
      } catch (error) {
        debugPrint('[Bootstrap] Reconciliation failed (non-fatal): $error');
      }
    });
  }
}
