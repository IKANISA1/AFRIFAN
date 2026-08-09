import 'dart:async';

import 'package:feat_game_operations/feat_game_operations.dart';

final testOwnedDisplay = OwnedDisplay(
  id: 'display-1',
  name: 'Living room TV',
  scopeType: 'home',
  pairingStatus: 'paired',
  health: 'online',
  appVersion: '2.0.0',
  lastSeenAt: DateTime.utc(2026, 7, 30, 9, 58),
  capabilities: <String, Object?>{
    'platform': 'android_tv',
    'remote_focus': true,
    'projection_version': 2,
  },
  assignedSessionId: 'session-1',
  assignedSession: const OwnedAssignedSession(
    id: 'session-1',
    title: 'Saturday club quiz',
    phase: 'scheduled',
  ),
);

final testDisplayInventory = OwnedDisplayInventory(
  clubId: '24',
  serverTime: DateTime.utc(2026, 7, 30, 10),
  displays: <OwnedDisplay>[testOwnedDisplay],
  scopeOptions: const <OwnedDisplayScopeOption>[
    OwnedDisplayScopeOption(scopeType: 'home', label: 'Home'),
    OwnedDisplayScopeOption(
      scopeType: 'venue',
      venueId: '99000000-0000-4000-8000-000000000081',
      label: 'Club House',
    ),
  ],
);

final testPlannerOptions = GamePlannerOptions(
  clubId: '24',
  serverTime: DateTime.utc(2026, 7, 30, 10),
  packs: <PlannerPack>[
    const PlannerPack(
      id: 'pack-1',
      title: 'Approved club quiz',
      description: 'Twenty reviewed questions',
      questionCount: 20,
    ),
  ],
  displays: <PlannerDisplay>[
    const PlannerDisplay(
      id: 'display-1',
      name: 'Living room TV',
      scopeType: 'home',
      pairingStatus: 'paired',
      health: 'online',
    ),
  ],
  invitees: const <PlannerInvitee>[
    PlannerInvitee(
      userId: 'supporter-1',
      displayName: 'Club supporter',
      publicUserId: '123456',
    ),
  ],
  allowedEligibilityScopes: const <String>[
    'club_membership',
    'invitation_only',
    'home_owner',
    'venue',
  ],
);

final testManagedGame = ManagedGameSession(
  clubId: '24',
  id: 'session-1',
  title: 'Saturday club quiz',
  packTitle: 'Approved club quiz',
  phase: 'scheduled',
  sessionVersion: 2,
  questionVersion: 0,
  eventSequence: 2,
  serverTime: DateTime.utc(2026, 7, 30, 10),
  scheduledStartAt: DateTime.utc(2026, 7, 31, 18),
  eligibilityScope: 'club_membership',
  allowedActions: const <String>['activated_lobby', 'cancelled'],
  participantCount: 0,
  assignedDisplays: const <ManagedDisplaySummary>[],
);

final testQuestionOpenManagedGame = ManagedGameSession(
  clubId: '24',
  id: 'session-1',
  title: 'Saturday club quiz',
  packTitle: 'Approved club quiz',
  phase: 'question_open',
  sessionVersion: 8,
  questionVersion: 2,
  eventSequence: 10,
  serverTime: DateTime.utc(2026, 7, 30, 10),
  phaseDeadline: DateTime.utc(2026, 7, 30, 10, 0, 30),
  scheduledStartAt: DateTime.utc(2026, 7, 31, 18),
  eligibilityScope: 'club_membership',
  allowedActions: const <String>[
    'reveal',
    'skip_question',
    'paused',
    'end_early',
    'cancelled',
  ],
  participantCount: 24,
  assignedDisplays: const <ManagedDisplaySummary>[],
  questionControls: const <ManagedQuestionSummary>[
    ManagedQuestionSummary(
      id: 'session-question-1',
      ordinal: 1,
      state: 'open',
      prompt: 'Who scored the opening goal?',
    ),
    ManagedQuestionSummary(
      id: 'session-question-2',
      ordinal: 2,
      state: 'queued',
      prompt: 'Which minute was the winner scored?',
    ),
  ],
  currentQuestion: const ManagedQuestionControl(
    id: 'session-question-1',
    ordinal: 1,
    state: 'open',
    prompt: 'Who scored the opening goal?',
    options: <Map<String, dynamic>>[
      <String, dynamic>{'key': 'a', 'label': 'The centre forward'},
      <String, dynamic>{'key': 'b', 'label': 'The captain'},
    ],
  ),
);

final testManagedInventory = ManagedGamesInventory(
  clubId: '24',
  serverTime: DateTime.utc(2026, 7, 30, 10),
  canPlan: true,
  sessions: <ManagedGameSession>[testManagedGame],
);

class FakeGameOperationsGateway implements GameOperationsGateway {
  OwnedDisplayInventory displayInventory = testDisplayInventory;
  ManagedGamesInventory managedInventory = testManagedInventory;
  GamePlannerOptions plannerOptions = testPlannerOptions;
  ManagedGameSession managedGame = testManagedGame;
  GameOperationsFailure? displayFailure;
  Completer<OwnedDisplayInventory>? displayFetchCompleter;
  GameOperationsFailure? managedFailure;
  Completer<ManagedGamesInventory>? managedFetchCompleter;
  Completer<GamePlannerOptions>? plannerFetchCompleter;
  Completer<ManagedGameSession>? managedGameFetchCompleter;
  Object? nextMutationError;
  int mutationFailuresRemaining = 0;
  int displayFetches = 0;
  int managedFetches = 0;
  int plannerFetches = 0;
  int managedGameFetches = 0;
  int claims = 0;
  int updates = 0;
  int revocations = 0;
  int recoveries = 0;
  int creations = 0;
  int transitions = 0;
  int skips = 0;
  int earlyEnds = 0;
  int assignments = 0;
  int unassignments = 0;
  final List<String> updateIdempotencyKeys = <String>[];
  final List<String> updatedDisplayNames = <String>[];
  final List<String> updatedScopeTypes = <String>[];
  final List<String?> updatedVenueIds = <String?>[];
  final List<String> revokeIdempotencyKeys = <String>[];
  final List<String> recoveryIdempotencyKeys = <String>[];
  final List<String> recoveryChallenges = <String>[];
  final List<String> createIdempotencyKeys = <String>[];
  final List<List<String>> createDisplayIds = <List<String>>[];
  final List<List<String>> createInviteeUserIds = <List<String>>[];
  final List<String> transitionIdempotencyKeys = <String>[];
  final List<DateTime?> transitionDeadlines = <DateTime?>[];
  final List<String> skipIdempotencyKeys = <String>[];
  final List<String> skipReasons = <String>[];
  final List<String> skippedToQuestionIds = <String>[];
  final List<String> earlyEndIdempotencyKeys = <String>[];
  final List<String> earlyEndReasons = <String>[];

  void _failMutationIfRequested() {
    final error = nextMutationError;
    if (error != null) {
      nextMutationError = null;
      throw error;
    }
    if (mutationFailuresRemaining <= 0) return;
    mutationFailuresRemaining--;
    throw const GameOperationsFailure(GameOperationsFailureKind.unavailable);
  }

  @override
  Future<OwnedDisplayInventory> fetchOwnedDisplays() async {
    displayFetches++;
    final failure = displayFailure;
    if (failure != null) throw failure;
    final pending = displayFetchCompleter;
    if (pending != null) return pending.future;
    return displayInventory;
  }

  @override
  Future<Map<String, dynamic>> claimDisplay({
    required String challenge,
    required String displayName,
    required String scopeType,
    String? venueId,
  }) async {
    claims++;
    _failMutationIfRequested();
    return <String, dynamic>{'display_id': 'display-2'};
  }

  @override
  Future<Map<String, dynamic>> updateDisplay({
    required String displayId,
    required String displayName,
    required String scopeType,
    required String idempotencyKey,
    String? venueId,
  }) async {
    updates++;
    updateIdempotencyKeys.add(idempotencyKey);
    updatedDisplayNames.add(displayName);
    updatedScopeTypes.add(scopeType);
    updatedVenueIds.add(venueId);
    _failMutationIfRequested();
    return <String, dynamic>{'display_id': displayId};
  }

  @override
  Future<Map<String, dynamic>> revokeDisplay({
    required String displayId,
    required String idempotencyKey,
  }) async {
    revocations++;
    revokeIdempotencyKeys.add(idempotencyKey);
    _failMutationIfRequested();
    return <String, dynamic>{'display_id': displayId, 'revoked': true};
  }

  @override
  Future<Map<String, dynamic>> recoverDisplay({
    required String displayId,
    required String challenge,
    required String idempotencyKey,
  }) async {
    recoveries++;
    recoveryChallenges.add(challenge);
    recoveryIdempotencyKeys.add(idempotencyKey);
    _failMutationIfRequested();
    return <String, dynamic>{
      'display_id': displayId,
      'status': 'recovery_pending_tv_exchange',
    };
  }

  @override
  Future<ManagedGamesInventory> fetchManagedGames() async {
    managedFetches++;
    final failure = managedFailure;
    if (failure != null) throw failure;
    final pending = managedFetchCompleter;
    if (pending != null) return pending.future;
    return managedInventory;
  }

  @override
  Future<ManagedGameSession> fetchManagedGame(String sessionId) async {
    managedGameFetches++;
    final failure = managedFailure;
    if (failure != null) throw failure;
    final pending = managedGameFetchCompleter;
    if (pending != null) return pending.future;
    return managedGame;
  }

  @override
  Future<GamePlannerOptions> fetchPlannerOptions() async {
    plannerFetches++;
    final failure = managedFailure;
    if (failure != null) throw failure;
    final pending = plannerFetchCompleter;
    if (pending != null) return pending.future;
    return plannerOptions;
  }

  @override
  Future<ManagedGameSession> createManagedGame({
    required String packId,
    required DateTime scheduledStartAt,
    required String eligibilityScope,
    required List<String> displayIds,
    required List<String> inviteeUserIds,
    required String idempotencyKey,
  }) async {
    creations++;
    createIdempotencyKeys.add(idempotencyKey);
    createDisplayIds.add(List<String>.of(displayIds));
    createInviteeUserIds.add(List<String>.of(inviteeUserIds));
    _failMutationIfRequested();
    return managedGame;
  }

  @override
  Future<ManagedGameSession> transitionManagedGame({
    required ManagedGameSession session,
    required String requestedPhase,
    required String idempotencyKey,
    DateTime? phaseDeadline,
    String? reason,
  }) async {
    transitions++;
    transitionIdempotencyKeys.add(idempotencyKey);
    transitionDeadlines.add(phaseDeadline);
    _failMutationIfRequested();
    managedGame = ManagedGameSession(
      clubId: session.clubId,
      id: session.id,
      title: session.title,
      packTitle: session.packTitle,
      phase: requestedPhase,
      sessionVersion: session.sessionVersion + 1,
      questionVersion: session.questionVersion,
      eventSequence: session.eventSequence + 1,
      serverTime: session.serverTime.add(const Duration(seconds: 1)),
      phaseDeadline: phaseDeadline,
      scheduledStartAt: session.scheduledStartAt,
      eligibilityScope: session.eligibilityScope,
      allowedActions: const <String>[],
      participantCount: session.participantCount,
      assignedDisplays: session.assignedDisplays,
      questionControls: session.questionControls,
      currentQuestion: session.currentQuestion,
    );
    return managedGame;
  }

  @override
  Future<ManagedGameSession> skipManagedGameQuestion({
    required ManagedGameSession session,
    required String nextSessionQuestionId,
    required String idempotencyKey,
    required String reason,
  }) async {
    skips++;
    skipIdempotencyKeys.add(idempotencyKey);
    skipReasons.add(reason);
    skippedToQuestionIds.add(nextSessionQuestionId);
    _failMutationIfRequested();
    final nextQuestion = session.questionControls.firstWhere(
      (question) => question.id == nextSessionQuestionId,
    );
    managedGame = ManagedGameSession(
      clubId: session.clubId,
      id: session.id,
      title: session.title,
      packTitle: session.packTitle,
      phase: 'question_open',
      sessionVersion: session.sessionVersion + 1,
      questionVersion: session.questionVersion + 1,
      eventSequence: session.eventSequence + 1,
      serverTime: session.serverTime.add(const Duration(seconds: 1)),
      phaseDeadline: session.phaseDeadline,
      scheduledStartAt: session.scheduledStartAt,
      eligibilityScope: session.eligibilityScope,
      allowedActions: session.allowedActions,
      participantCount: session.participantCount,
      assignedDisplays: session.assignedDisplays,
      questionControls: session.questionControls,
      currentQuestion: ManagedQuestionControl(
        id: nextQuestion.id,
        ordinal: nextQuestion.ordinal,
        state: 'open',
        prompt: nextQuestion.prompt,
        options: const <Map<String, dynamic>>[],
      ),
    );
    return managedGame;
  }

  @override
  Future<ManagedGameSession> endManagedGameEarly({
    required ManagedGameSession session,
    required String idempotencyKey,
    required String reason,
  }) async {
    earlyEnds++;
    earlyEndIdempotencyKeys.add(idempotencyKey);
    earlyEndReasons.add(reason);
    _failMutationIfRequested();
    managedGame = ManagedGameSession(
      clubId: session.clubId,
      id: session.id,
      title: session.title,
      packTitle: session.packTitle,
      phase: 'completed',
      sessionVersion: session.sessionVersion + 1,
      questionVersion: session.questionVersion,
      eventSequence: session.eventSequence + 1,
      serverTime: session.serverTime.add(const Duration(seconds: 1)),
      scheduledStartAt: session.scheduledStartAt,
      eligibilityScope: session.eligibilityScope,
      allowedActions: const <String>[],
      participantCount: session.participantCount,
      assignedDisplays: session.assignedDisplays,
      questionControls: session.questionControls,
      currentQuestion: session.currentQuestion,
    );
    return managedGame;
  }

  @override
  Future<void> assignDisplay({
    required String sessionId,
    required String displayId,
    required String idempotencyKey,
  }) async {
    assignments++;
  }

  @override
  Future<void> unassignDisplay({
    required String sessionId,
    required String displayId,
    required String idempotencyKey,
  }) async {
    unassignments++;
  }
}
