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

  testWidgets('get permissions returns without error', (tester) async {
    final permissions = await client.getPermissions();
    // May be empty, but should not throw
    for (final permission in permissions) {
      expect(permission.id, isNotEmpty,
          reason: 'Permission id should be non-empty');
      expect(permission.sessionId, isNotEmpty,
          reason: 'Permission sessionId should be non-empty');
    }
  });

  testWidgets('abort idle session handles error gracefully', (tester) async {
    final sessions = await client.listSessions();
    if (sessions.isEmpty) return;

    // Find an idle session
    final idleSession = sessions.where((s) => s.status == SessionStatus.idle).firstOrNull;
    if (idleSession == null) return;

    // Aborting an idle session may fail, but should not crash
    try {
      await client.abortSession(idleSession.id);
    } on OpenCodeException catch (_) {
      // Expected - aborting an idle session may return an error
    }
  });
}
