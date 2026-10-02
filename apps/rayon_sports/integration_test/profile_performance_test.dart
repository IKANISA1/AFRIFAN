import 'dart:developer' as developer;

import 'package:app_registry/app_registry.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:core_app/bootstrap.dart';
import 'package:core_auth/core_auth.dart';
import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/match_card.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:feat_settings/src/support_whatsapp_provider.dart';
import 'package:feat_shop/src/screens/cart_screen.dart';
import 'package:feat_shop/src/screens/shop_screen.dart';
import 'package:feat_shop/src/shop_cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:test_support/app_font_loader.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const physicalDeviceProfile = bool.fromEnvironment(
    'AFRICLUB_PHYSICAL_DEVICE_PROFILE',
  );

  setUpAll(loadAppFonts);

  testWidgets('profiles authenticated home to settings transition and scroll', (
    tester,
  ) async {
    var orderSubmissionAttempted = false;
    final startupStopwatch = Stopwatch()..start();
    await bootstrap(
      const _ProfileRayonSportsConfig(),
      options: AfriClubBootstrapOptions(
        modules: AppModuleRegistry.build(const _ProfileRayonSportsConfig()),
        startupOptions: const AppStartupOptions.integrationTest(),
        authRepository: _ProfileAuthRepository(),
        providerOverrides: [
          initialFeatureConfigSnapshotProvider.overrideWithValue(
            _profileFeatureSnapshot,
          ),
          homeFeedRepositoryProvider.overrideWithValue(
            const _ProfileHomeFeedRepository(),
          ),
          latestIntelRepositoryProvider.overrideWithValue(
            const _ProfileLatestIntelRepository(),
          ),
          currentUserProvider.overrideWith((ref) => _profileUser),
          supportWhatsAppProvider.overrideWith((ref) async => '250788000000'),
        ],
      ),
    );

    await _scrollHomeUntilVisible(tester, find.byType(QuickActionsGrid));
    startupStopwatch.stop();

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['profile_scope'] = <String, dynamic>{
      'app_bootstrap_to_home_ms': startupStopwatch.elapsedMilliseconds,
      'build_mode': 'profile_required',
      'data_source': 'controlled_non_production_providers',
      'frame_budget_ms': 16,
      'live_backend_used': false,
      'physical_device_claimed': physicalDeviceProfile,
    };

    await _watchPerformanceOrRun(binding, () async {
      final context = tester.element(find.byType(QuickActionsGrid));
      GoRouter.of(context).go('/settings');
      await _pumpUntilVisible(tester, find.text('Settings'));
      await _pumpUntilVisible(tester, find.text('Edit profile'));
    }, reportKey: 'home_to_settings_transition_frames');

    final scrollable = find.byType(Scrollable).first;
    await _watchPerformanceOrRun(binding, () async {
      for (var index = 0; index < 4; index++) {
        await tester.fling(scrollable, const Offset(0, -600), 1200);
        await tester.pumpAndSettle();
        await tester.fling(scrollable, const Offset(0, 600), 1200);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'settings_scroll_frames');

    expect(find.text('Settings'), findsOneWidget);

    ConnectivityService.setOnlineForTest(true);
    AfriCountryCatalog.withCountries(const [_profileCountry]);
    AfriCountryCatalog.setPreferredCountryCode('RW');
    addTearDown(() {
      AfriCountryCatalog.withCountries(const <AfriCountry>[]);
      AfriCountryCatalog.setPreferredCountryCode(null);
    });
    final shopRouter = _profileShopRouter(
      onOrderSubmission: () => orderSubmissionAttempted = true,
    );
    addTearDown(shopRouter.dispose);
    await tester.pumpWidget(_profileShopApp(shopRouter));
    await _pumpUntilVisible(tester, find.text('Profile product 0'));

    final catalogScroll = find.byType(CustomScrollView);
    expect(catalogScroll, findsOneWidget);
    await _watchPerformanceOrRun(binding, () async {
      for (var index = 0; index < 6; index++) {
        await tester.fling(catalogScroll, const Offset(0, -900), 1800);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'shop_120_item_list_scroll_frames');

    await _watchPerformanceOrRun(binding, () async {
      await tester.tap(find.text('Checkout').last);
      await _pumpUntilVisible(tester, find.text('Delivery address'));
      await _pumpUntilVisible(tester, find.text('Checkout via MOMO'));
    }, reportKey: 'shop_to_checkout_transition_frames');

    final addressField = find.byType(TextField).first;
    final checkoutScroll = find.byType(SingleChildScrollView);
    expect(checkoutScroll, findsOneWidget);
    await _watchPerformanceOrRun(binding, () async {
      await tester.enterText(addressField, '12 Amahoro Avenue');
      await tester.fling(checkoutScroll, const Offset(0, -700), 1400);
      await tester.pumpAndSettle();
      await tester.fling(checkoutScroll, const Offset(0, 700), 1400);
      await tester.pumpAndSettle();
    }, reportKey: 'checkout_form_interaction_frames');

    expect(
      orderSubmissionAttempted,
      isFalse,
      reason: 'Checkout submission is outside this performance scenario.',
    );

    binding.reportData!['profile_scope'] = <String, dynamic>{
      ...binding.reportData!['profile_scope'] as Map<String, dynamic>,
      'shop_catalog_item_count': _profileProducts.length,
      'shop_images_profiled': false,
      'checkout_submission_profiled': false,
      'memory_budget_declared': false,
      'realtime_profiled': false,
    };
  });
}

Widget _profileShopApp(GoRouter router) {
  final config = ClubConfig.fallback();
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_profileUser),
      storeReleasePolicyProvider.overrideWithValue(
        const StoreReleasePolicy.unenforced(),
      ),
      shopCartProvider.overrideWith((ref) => _ProfileCartNotifier()),
    ],
    child: MaterialApp.router(
      theme: ClubTheme.from(config, brightness: Brightness.dark),
      routerConfig: router,
      builder: (context, child) => ClubConfigScope(
        config: config,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

GoRouter _profileShopRouter({
  required void Function() onOrderSubmission,
}) => GoRouter(
  initialLocation: '/shop',
  routes: [
    GoRoute(
      path: '/shop',
      builder: (context, state) =>
          ShopScreen(productLoader: () async => _profileProducts),
      routes: [
        GoRoute(
          path: 'cart',
          builder: (context, state) => CartScreen(
            paymentRouteLoader: (_) async => _profilePaymentRoute,
            orderPlacer:
                ({
                  required userId,
                  required partnerId,
                  required items,
                  required deliveryAddress,
                  required paymentReference,
                }) async {
                  onOrderSubmission();
                  throw UnsupportedError(
                    'Checkout submission is outside this performance scenario',
                  );
                },
          ),
        ),
      ],
    ),
  ],
);

final _profileProducts = List<Map<String, dynamic>>.generate(
  120,
  (index) => <String, dynamic>{
    'id': 'profile-product-$index',
    'name': 'Profile product $index',
    'description': 'Controlled non-production performance item $index',
    'category': index.isEven ? 'Jerseys' : 'Accessories',
    'price': 15000 + (index * 100),
    'stock': 20,
    'is_active': true,
    'is_new': index < 8,
    'sort_order': index,
  },
  growable: false,
);

class _ProfileCartNotifier extends ShopCartNotifier {
  _ProfileCartNotifier() {
    for (final product in _profileProducts.take(4)) {
      addRawProduct(product, partnerId: _profileUser.clubId);
    }
  }
}

const _profilePaymentRoute = PartnerPaymentRoute(
  id: 'profile-payment-route',
  partnerId: '24',
  partnerName: 'Rayon Sports',
  partnerSlug: 'rayon-sports',
  countryCode: 'RW',
  providerId: 'mtn',
  recipientCode: '1828',
  reconciliationLabel: 'Profile shop orders',
  status: PartnerPaymentRouteStatus.active,
);

const _profileCountry = AfriCountry(
  isoCode: 'RW',
  dialCode: '+250',
  name: 'Rwanda',
  flagEmoji: '',
  currencyCode: 'RWF',
  currencyName: 'Rwandan franc',
  momoUssdTemplate: '*182*1*1*{recipient}*{amount}#',
  momoCodeUssdTemplate: '*182*8*1*{recipient}*{amount}#',
);

const _profileUser = UserProfile(
  id: 'profile-user',
  clubId: '24',
  publicUserId: '483912',
  momoNumber: '0788123456',
  momoProvider: 'MoMo',
  languageCode: 'en',
);

const _profileFeatureSnapshot = PlatformConfigSnapshot(
  contentBlocks: <ContentBlock>[
    ContentBlock(
      blockKey: 'profile_home_hero',
      blockType: 'widget',
      content: <String, dynamic>{'widget': 'match_score_card'},
      placementKey: 'home_hero',
      sortOrder: 0,
    ),
    ContentBlock(
      blockKey: 'profile_home_quick_actions',
      blockType: 'widget',
      content: <String, dynamic>{'widget': 'quick_actions_grid'},
      placementKey: 'home_top',
      sortOrder: 10,
    ),
    ContentBlock(
      blockKey: 'profile_home_latest_intel',
      blockType: 'widget',
      content: <String, dynamic>{'widget': 'latest_intel_section'},
      placementKey: 'home_bottom',
      sortOrder: 20,
    ),
  ],
);

class _ProfileRayonSportsConfig extends RayonSportsConfig {
  const _ProfileRayonSportsConfig();

  @override
  String get clubId => '24';

  @override
  String get supabaseUrl => 'https://example.supabase.co';

  @override
  String get supabaseAnonKey => 'anon';

  @override
  String get environment => 'profile_test';
}

class _ProfileAuthRepository extends AuthRepository {
  _ProfileAuthRepository() : super(clubId: '24');

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async =>
      AdminWorkspaceAccess.none;

  @override
  Future<UserProfile?> restoreCurrentUser() async => _profileUser;

  @override
  Future<UserProfile> signInAnonymously() async =>
      throw UnimplementedError('Anonymous sign-in is not profiled.');

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async => profile;
}

class _ProfileHomeFeedRepository implements HomeFeedRepository {
  const _ProfileHomeFeedRepository();

  @override
  Future<HomeFeedSnapshot> load() async => const HomeFeedSnapshot(
    heroSlides: [
      MatchSlide(
        homeTeam: 'RAYON SPORTS',
        awayTeam: 'Rayon Sports FC',
        venue: 'AMAHORO STADIUM',
        status: 'ON SALE',
        dateInfo: '12 Rayon Sports • 18:00',
        route: '/tickets',
      ),
    ],
    status: HomeFeedStatus.success,
  );
}

class _ProfileLatestIntelRepository implements LatestIntelRepository {
  const _ProfileLatestIntelRepository();

  @override
  Future<LatestIntelSnapshot> loadPublishedArticles() async =>
      const LatestIntelSnapshot(
        status: LatestIntelStatus.ready,
        articles: [
          {
            'id': 'profile-article',
            'title': 'Training ground update',
            'subtitle': 'First-team preparations continue this week.',
          },
        ],
      );
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 80,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> _watchPerformanceOrRun(
  IntegrationTestWidgetsFlutterBinding binding,
  Future<void> Function() action, {
  required String reportKey,
}) async {
  final serviceInfo = await developer.Service.getInfo();
  if (serviceInfo.serverUri == null) {
    await action();
    binding.reportData ??= <String, dynamic>{};
    binding.reportData![reportKey] = <String, dynamic>{
      'captured': false,
      'reason': 'vm_service_unavailable_in_host_flutter_test',
    };
    return;
  }

  await binding.watchPerformance(action, reportKey: reportKey);
}

Future<void> _scrollHomeUntilVisible(WidgetTester tester, Finder finder) async {
  final topChrome = find.byKey(const ValueKey<String>('home-top-chrome'));
  await _pumpUntilVisible(tester, topChrome);

  final homeScrollable = find.ancestor(
    of: topChrome,
    matching: find.byType(Scrollable),
  );
  expect(homeScrollable, findsOneWidget);

  await tester.scrollUntilVisible(finder, 240, scrollable: homeScrollable);
  await tester.pumpAndSettle();
}
