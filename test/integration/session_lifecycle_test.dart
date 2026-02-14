import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
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

  testWidgets('session lifecycle: create, send message, get messages, delete',
      (tester) async {
    final session = await client.createSession(input: SessionCreateInput(title: 'Integration Test Session'));
    expect(session.id, isNotEmpty);

    try {
      // Send a message
      final response = await client.sendMessage(
        session.id,
        text: 'Hello, this is an integration test.',
      );
      expect(response.id, isNotEmpty);
      expect(response.sessionId, isNotEmpty);

      // Get messages
      final messages = await client.getMessages(session.id);
      expect(messages, isNotEmpty, reason: 'Should have at least the user message');
    } finally {
      // Clean up: delete session
      await client.deleteSession(session.id);
    }

    // Verify deletion
    try {
      await client.getSession(session.id);
      fail('Session should have been deleted');
    } on OpenCodeException catch (_) {
      // Expected - session no longer exists
    }
  });
}
