import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:feat_fan_clubs/src/providers/fan_club_detail_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  test('loads approved fan club data', () async {
    final gateway = _Gateway(results: [_data()]);
    final controller = FanClubDetailController(
      gateway,
      'club-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.value!.data?.club['name'], 'Blue Family');
    expect(controller.state.value!.phase, FanClubDetailPhase.ready);
  });

  test('represents a missing fan club as empty data', () async {
    final controller = FanClubDetailController(
      _Gateway(results: [null]),
      'missing',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.value!.data, isNull);
  });

  test('fails offline before gateway access', () async {
    ConnectivityService.setOnlineForTest(false);
    final gateway = _Gateway(results: [_data()]);
    final controller = FanClubDetailController(
      gateway,
      'club-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(gateway.calls, 0);
    expect(
      controller.state.error,
      const TypeMatcher<FanClubDetailFailure>().having(
        (failure) => failure.kind,
        'kind',
        FanClubDetailFailureKind.offline,
      ),
    );
  });

  test('maps a bounded read timeout to security timeout', () async {
    final controller = FanClubDetailController(
      _Gateway(completer: Completer<FanClubDetailData?>()),
      'club-1',
      autoLoad: false,
      loadTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(
      controller.state.error,
      const TypeMatcher<FanClubDetailFailure>().having(
        (failure) => failure.kind,
        'kind',
        FanClubDetailFailureKind.securityTimeout,
      ),
    );
  });

  test('maps authorization failures without exposing the raw error', () async {
    final controller = FanClubDetailController(
      _Gateway(error: StateError('row-level security denied raw query')),
      'club-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();

    final failure = controller.state.error as FanClubDetailFailure;
    expect(failure.kind, FanClubDetailFailureKind.permissionDenied);
    expect(failure.toString(), isNot(contains('raw query')));
  });

  test('retains confirmed data when refresh conflicts', () async {
    final gateway = _Gateway(
      results: [_data()],
      followUpError: StateError('stale revision'),
    );
    final controller = FanClubDetailController(
      gateway,
      'club-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.refresh();

    final state = controller.state.value!;
    expect(state.data?.club['name'], 'Blue Family');
    expect(state.phase, FanClubDetailPhase.degraded);
    expect(state.failure?.kind, FanClubDetailFailureKind.conflict);
  });

  test('coalesces overlapping refreshes', () async {
    final completer = Completer<FanClubDetailData?>();
    final gateway = _Gateway(completer: completer);
    final controller = FanClubDetailController(
      gateway,
      'club-1',
      autoLoad: false,
    );
    addTearDown(controller.dispose);

    final first = controller.load();
    final second = controller.refresh();
    completer.complete(_data());
    await Future.wait([first, second]);

    expect(gateway.calls, 1);
  });
}

class _Gateway implements FanClubDetailGateway {
  _Gateway({
    this.results = const [],
    this.error,
    this.followUpError,
    this.completer,
  });

  final List<FanClubDetailData?> results;
  final Object? error;
  final Object? followUpError;
  final Completer<FanClubDetailData?>? completer;
  int calls = 0;

  @override
  Future<FanClubDetailData?> load(String routeId) async {
    calls += 1;
    if (calls > 1 && followUpError != null) throw followUpError!;
    if (error != null) throw error!;
    if (completer != null) return completer!.future;
    return results[calls - 1];
  }
}

FanClubDetailData _data() => const FanClubDetailData(
  club: {
    'id': 'club-1',
    'slug': 'blue-family',
    'name': 'Blue Family',
    'description': 'Supporters across Kigali.',
    'region': 'Kigali',
    'member_count': 42,
    'is_active': true,
    'source_label': 'Approved public register',
  },
  upcomingMatch: {
    'home_team': 'Rayon Sports',
    'away_team': 'APR FC',
    'competition': 'Rwanda Premier League',
    'venue': 'Amahoro Stadium',
    'match_date': '2026-08-02',
    'kickoff_time': '17:00',
  },
);
