import 'dart:convert';
import 'dart:io';

import 'package:club_as_vita/club_as_vita.dart';
import 'package:club_costa_do_sol/club_costa_do_sol.dart';
import 'package:club_nkana/club_nkana.dart';
import 'package:club_rayon_sports/club_rayon_sports.dart';
import 'package:club_vitalo/club_vitalo.dart';
import 'package:core_theme/core_theme.dart';

/// Real compiled club identity/capability data with isolated test endpoints.
/// No production initialization, credential or network access is performed.
Map<String, ClubConfig> fiveClubFixtures(Directory workspace) {
  final originals = <String, ClubConfig>{
    'as_vita': const AsVitaConfig(),
    'costa_do_sol': const CostaDoSolConfig(),
    'nkana': const NkanaConfig(),
    'rayon_sports': const RayonSportsConfig(),
    'vitalo': const VitaloConfig(),
  };
  return originals.map((slug, config) {
    final input =
        jsonDecode(
              File(
                '${workspace.path}/apps/$slug/assets/flavors/production.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    return MapEntry(slug, _IsolatedConfig(config, input['CLUB_ID']! as String));
  });
}

class _IsolatedConfig implements ClubConfig {
  const _IsolatedConfig(
    this.base,
    this.clubId, {
    this.internalMobileAdmin = false,
  });
  final ClubConfig base;
  final bool internalMobileAdmin;
  @override
  final String clubId;
  @override
  String get clubName => base.clubName;
  @override
  String get appName => base.appName;
  @override
  String get country => base.country;
  @override
  String get countryCode => base.countryCode;
  @override
  String get language => base.language;
  @override
  String get momoPrefix => base.momoPrefix;
  @override
  String get currency => base.currency;
  @override
  String get currencySymbol => base.currencySymbol;
  @override
  ClubColors get colors => base.colors;
  @override
  String get supabaseUrl => 'https://synthetic.example.invalid';
  @override
  String get supabaseAnonKey => 'synthetic-unused';
  @override
  List<String> get supportedLanguages => base.supportedLanguages;
  @override
  bool get hasFanClubs => base.hasFanClubs;
  @override
  bool get hasShop => base.hasShop;
  @override
  bool get hasTicketing => base.hasTicketing;
  @override
  bool get hasChat => base.hasChat;
  @override
  MomoConfig get momo => base.momo;
  @override
  String get environment => 'isolated-local-fixture';
  @override
  Map<String, bool> get features => {
    ...base.features,
    if (internalMobileAdmin) 'mobile_admin': true,
  };
}

/// Separate declared internal-build scope; consumer capabilities stay exact.
/// This does not mutate or authorize the production consumer configuration.
ClubConfig internalAdminFixtureConfig(ClubConfig config) =>
    _IsolatedConfig(config, config.clubId, internalMobileAdmin: true);
