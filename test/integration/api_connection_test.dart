import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  testWidgets('health check returns healthy with version', (tester) async {
    final result = await client.healthCheck();

    if (!result.healthy) {
      fail('Health check failed: ${result.error ?? "unknown error"}\n'
          'Server URL: $serverUrl\n'
          'Using Cronet: ${platformHttpClient.isUsingCronet}');
    }
    expect(result.version, isNotNull, reason: 'Version should be present');
    expect(result.version, isNotEmpty, reason: 'Version should not be empty');
    expect(result.error, isNull, reason: 'No error expected');
  });

  testWidgets('list sessions returns non-empty list', (tester) async {
    final sessions = await client.listSessions();

    expect(sessions, isNotEmpty, reason: 'Should have at least one session');

    final session = sessions.first;
    expect(session.id, isNotEmpty, reason: 'Session id should be non-empty');
    expect(session.createdAt, isNotNull, reason: 'createdAt should be set');
  });

  testWidgets('get single session returns valid data', (tester) async {
    final sessions = await client.listSessions();
    expect(sessions, isNotEmpty);

    final sessionId = sessions.first.id;
    final session = await client.getSession(sessionId);

    expect(session.id, equals(sessionId));
    expect(session.createdAt, isNotNull);
  });

  testWidgets('session fields parsed correctly including projectId',
      (tester) async {
    final sessions = await client.listSessions();
    expect(sessions, isNotEmpty);

    final session = sessions.first;
    expect(session.id, isNotEmpty);
    expect(session.createdAt, isNotNull);
    // projectId may be null for sessions not tied to a project
    // but the field should be parseable without error
    // Status should be a valid enum value
    expect(SessionStatus.values, contains(session.status));
  });

  testWidgets('get messages for existing session returns valid messages',
      (tester) async {
    final sessions = await client.listSessions();
    expect(sessions, isNotEmpty);

    final sessionId = sessions.first.id;
    final messages = await client.getMessages(sessionId);

    // Session may or may not have messages; just validate no crash
    for (final message in messages) {
      expect(message.id, isNotEmpty, reason: 'Message id should be non-empty');
      expect(message.sessionId, isNotEmpty,
          reason: 'Message sessionId should be non-empty');
      expect(message.parts, isNotNull, reason: 'Parts should not be null');
    }
  });
}
