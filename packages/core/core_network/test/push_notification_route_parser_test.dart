import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sessionId = '99000000-0000-4000-8000-000000000031';

  test('GAME-MOB-01 maps a valid live-game push to code-free discovery', () {
    final route = PushNotificationRouteParser.parse(<String, dynamic>{
      'type': 'live_game',
      'session_id': sessionId.toUpperCase(),
      'route': '/admin',
    });

    expect(route, Uri.parse('/fanzone/game/$sessionId'));
  });

  test('GAME-MOB-01 rejects ungoverned or malformed push destinations', () {
    expect(
      PushNotificationRouteParser.parse(<String, dynamic>{
        'type': 'news',
        'session_id': sessionId,
      }),
      isNull,
    );
    expect(
      PushNotificationRouteParser.parse(<String, dynamic>{
        'type': 'live_game',
        'session_id': '../admin',
      }),
      isNull,
    );
    expect(
      PushNotificationRouteParser.parse(<String, dynamic>{
        'type': 'live_game',
        'session_id': 'TV-CODE-123',
      }),
      isNull,
    );
  });
}
