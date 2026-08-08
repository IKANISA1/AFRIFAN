import 'package:feat_game_operations/feat_game_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'owner inventory validates club identity and parses only safe fields',
    () {
      final inventory = OwnedDisplayInventory.fromJson(<String, dynamic>{
        'club_id': '24',
        'server_time': '2026-07-30T10:00:00Z',
        'scope_options': <Object?>[
          <String, dynamic>{
            'scope_type': 'home',
            'venue_id': null,
            'label': 'Home',
          },
          <String, dynamic>{
            'scope_type': 'venue',
            'venue_id': '99000000-0000-4000-8000-000000000081',
            'label': 'Club House',
          },
        ],
        'displays': <Object?>[
          <String, dynamic>{
            'display_id': 'display-1',
            'display_name': 'Living room',
            'scope_type': 'home',
            'pairing_status': 'paired',
            'health': 'online',
            'last_seen_at': '2026-07-30T09:58:00Z',
            'app_version': '1.0.0',
            'capabilities': <String, Object?>{
              'platform': 'android_tv',
              'remote_focus': true,
              'projection_version': 2,
            },
            'assigned_session': <String, dynamic>{
              'session_id': 'session-1',
              'title': 'Saturday club quiz',
              'phase': 'scheduled',
            },
          },
        ],
      }, expectedClubId: '24');

      expect(inventory.displays.single.name, 'Living room');
      expect(inventory.displays.single.assignedSessionId, 'session-1');
      expect(
        inventory.displays.single.assignedSession?.title,
        'Saturday club quiz',
      );
      expect(inventory.displays.single.capabilities['remote_focus'], isTrue);
      expect(inventory.displays.single.lastSeenAt, isNotNull);
      expect(inventory.scopeOptions, hasLength(2));
      expect(inventory.scopeOptions.last.key, contains('99000000'));
    },
  );

  test('cross-club projections fail closed', () {
    expect(
      () => OwnedDisplayInventory.fromJson(<String, dynamic>{
        'club_id': '99',
        'server_time': '2026-07-30T10:00:00Z',
        'scope_options': <Object?>[],
        'displays': <Object?>[],
      }, expectedClubId: '24'),
      throwsA(
        isA<GameOperationsFailure>().having(
          (failure) => failure.kind,
          'kind',
          GameOperationsFailureKind.permissionDenied,
        ),
      ),
    );
  });

  test('owner scope options reject cross-contract identifiers', () {
    expect(
      () => OwnedDisplayScopeOption.fromJson(<String, dynamic>{
        'scope_type': 'venue',
        'venue_id': 'raw-venue-name',
        'label': 'Unsafe venue',
      }),
      throwsFormatException,
    );
    expect(
      () => OwnedDisplayScopeOption.fromJson(<String, dynamic>{
        'scope_type': 'home',
        'venue_id': '99000000-0000-4000-8000-000000000081',
        'label': 'Home',
      }),
      throwsFormatException,
    );
  });

  test('credential and pairing material are rejected by client models', () {
    expect(
      () => OwnedDisplay.fromJson(<String, dynamic>{
        'display_id': 'display-1',
        'display_name': 'Living room',
        'scope_type': 'home',
        'pairing_status': 'paired',
        'health': 'online',
        'device_credential': 'must-not-cross-the-projection',
      }),
      throwsFormatException,
    );
    expect(
      () => OwnedDisplay.fromJson(<String, dynamic>{
        'display_id': 'display-1',
        'display_name': 'Living room',
        'scope_type': 'home',
        'pairing_status': 'paired',
        'health': 'online',
        'capabilities': <String, Object?>{
          'unsafe_nested': <String, Object?>{'token': 'not-allowed'},
        },
      }),
      throwsFormatException,
    );
  });

  test('organizer projection rejects correct-answer material', () {
    expect(
      () => ManagedGameSession.fromJson(<String, dynamic>{
        'club_id': '24',
        'session_id': 'session-1',
        'session_title': 'Quiz',
        'pack_title': 'Pack',
        'phase': 'question_open',
        'session_version': 2,
        'question_version': 1,
        'event_sequence': 3,
        'server_time': '2026-07-30T10:00:00Z',
        'eligibility_scope': 'club_membership',
        'allowed_actions': <String>['reveal'],
        'participant_count': 1,
        'assigned_displays': <Object?>[],
        'current_question_control': <String, dynamic>{
          'id': 'question-1',
          'ordinal': 1,
          'state': 'open',
          'prompt': 'Question',
          'options': <Object?>[],
          'correct_option_key': 'a',
        },
      }, expectedClubId: '24'),
      throwsFormatException,
    );
  });

  test('planner marks actively assigned displays unavailable', () {
    final options = GamePlannerOptions.fromJson(<String, dynamic>{
      'club_id': '24',
      'server_time': '2026-07-30T10:00:00Z',
      'packs': <Object?>[],
      'displays': <Object?>[
        <String, dynamic>{
          'display_id': 'display-1',
          'display_name': 'Living room',
          'scope_type': 'home',
          'pairing_status': 'paired',
          'health': 'online',
          'assigned_session_id': 'session-1',
        },
      ],
      'invitees': <Object?>[
        <String, dynamic>{
          'user_id': 'supporter-1',
          'display_name': 'Club supporter',
          'public_user_id': '123456',
        },
      ],
      'allowed_eligibility_scopes': <String>[
        'club_membership',
        'invitation_only',
      ],
    }, expectedClubId: '24');

    expect(options.displays.single.isAvailable, isFalse);
    expect(options.invitees.single.publicUserId, '123456');
  });

  test(
    'planner invitees reject private identity fields and invalid Fan IDs',
    () {
      expect(
        () => PlannerInvitee.fromJson(<String, dynamic>{
          'user_id': 'supporter-1',
          'display_name': 'Club supporter',
          'public_user_id': '123456',
          'phone': '+250700000000',
        }),
        throwsFormatException,
      );
      expect(
        () => PlannerInvitee.fromJson(<String, dynamic>{
          'user_id': 'supporter-1',
          'display_name': 'Club supporter',
          'public_user_id': 'not-a-fan-id',
        }),
        throwsFormatException,
      );
    },
  );

  test('organizer projection exposes only safe ordered question controls', () {
    final session = ManagedGameSession.fromJson(<String, dynamic>{
      'club_id': '24',
      'session_id': 'session-1',
      'session_title': 'Quiz',
      'pack_title': 'Pack',
      'phase': 'question_open',
      'session_version': 8,
      'question_version': 2,
      'event_sequence': 10,
      'server_time': '2026-07-30T10:00:00Z',
      'eligibility_scope': 'club_membership',
      'allowed_actions': <String>['reveal', 'skip_question'],
      'participant_count': 2,
      'assigned_displays': <Object?>[],
      'question_controls': <Object?>[
        <String, dynamic>{
          'id': 'question-3',
          'ordinal': 3,
          'state': 'queued',
          'prompt': 'Third question',
        },
        <String, dynamic>{
          'id': 'question-2',
          'ordinal': 2,
          'state': 'queued',
          'prompt': 'Second question',
        },
      ],
      'current_question_control': <String, dynamic>{
        'id': 'question-1',
        'ordinal': 1,
        'state': 'open',
        'prompt': 'First question',
        'options': <Object?>[],
      },
    }, expectedClubId: '24');

    expect(session.nextQuestion?.id, 'question-2');
    expect(session.nextQuestion?.prompt, 'Second question');
    expect(
      () => ManagedQuestionSummary.fromJson(<String, dynamic>{
        'id': 'question-2',
        'ordinal': 2,
        'state': 'queued',
        'prompt': 'Second question',
        'correct_option_key': 'private',
      }),
      throwsFormatException,
    );
  });
}
