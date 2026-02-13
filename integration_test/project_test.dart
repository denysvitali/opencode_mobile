import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('list projects returns valid data', (tester) async {
    final projects = await client.listProjects();

    // Server may have zero or more projects
    for (final project in projects) {
      expect(project.id, isNotEmpty, reason: 'Project id should be non-empty');
    }
  });

  testWidgets('sessions have parseable projectId field', (tester) async {
    final sessions = await client.listSessions();
    if (sessions.isEmpty) return;

    // Verify projectId is parseable (may be null)
    for (final session in sessions) {
      // projectId is a String? - should not throw
      if (session.projectId != null) {
        expect(session.projectId, isNotEmpty,
            reason: 'Non-null projectId should not be empty');
      }
    }
  });
}
