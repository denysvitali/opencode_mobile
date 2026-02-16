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
      markTestSkipped('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
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

  group('OpenCodeClient.listSessions', () {
    testWidgets('returns list of sessions', (tester) async {
      final sessions = await client.listSessions();

      expect(sessions, isA<List<Session>>());
      expect(sessions, isNotEmpty, reason: 'Should have at least one session from mock server setup');
    });

    testWidgets('handles directory filter', (tester) async {
      final sessions = await client.listSessions(directory: '/test');

      expect(sessions, isA<List<Session>>());
    });

    testWidgets('handles search filter', (tester) async {
      final sessions = await client.listSessions(search: 'test');

      expect(sessions, isA<List<Session>>());
    });

    testWidgets('handles roots filter', (tester) async {
      final sessions = await client.listSessions(roots: true);

      expect(sessions, isA<List<Session>>());
    });
  });

  group('OpenCodeClient.createSession', () {
    testWidgets('creates new session', (tester) async {
      final session = await client.createSession();

      expect(session.id, isNotEmpty);
      expect(session.status, equals(SessionStatus.idle));
    });

    testWidgets('creates session with title', (tester) async {
      const title = 'Test Session Title';
      final session = await client.createSession(
        input: SessionCreateInput(title: title),
      );

      expect(session.id, isNotEmpty);
      expect(session.title, equals(title));
    });

    testWidgets('creates session with parentID', (tester) async {
      final parent = await client.createSession(
        input: SessionCreateInput(title: 'Parent Session'),
      );

      final child = await client.createSession(
        input: SessionCreateInput(parentID: parent.id),
      );

      expect(child.id, isNotEmpty);
      expect(child.parentID, equals(parent.id));
    });
  });

  group('OpenCodeClient.getSession', () {
    testWidgets('gets single session by ID', (tester) async {
      final created = await client.createSession(
        input: SessionCreateInput(title: 'Get Test Session'),
      );

      final session = await client.getSession(created.id);

      expect(session.id, equals(created.id));
      expect(session.title, equals('Get Test Session'));
    });

    testWidgets('returns 404 for non-existent session', (tester) async {
      expect(
        () => client.getSession('non-existent-id'),
        throwsA(isA<OpenCodeException>()),
      );
    });
  });

  group('OpenCodeClient.updateSession', () {
    testWidgets('updates session title', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Original Title'),
      );

      final updated = await client.updateSession(
        session.id,
        SessionUpdateInput(title: 'Updated Title'),
      );

      expect(updated.title, equals('Updated Title'));
    });

    testWidgets('archives session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Archive Test'),
      );

      final archived = await client.updateSession(
        session.id,
        SessionUpdateInput(archivedAt: DateTime.now().millisecondsSinceEpoch),
      );

      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, isNotNull);
    });
  });

  group('OpenCodeClient.deleteSession', () {
    testWidgets('deletes existing session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Delete Test'),
      );

      final result = await client.deleteSession(session.id);

      expect(result, isTrue);

      expect(
        () => client.getSession(session.id),
        throwsA(isA<OpenCodeException>()),
      );
    });

    testWidgets('returns error for non-existent session', (tester) async {
      expect(
        () => client.deleteSession('non-existent-id'),
        throwsA(isA<OpenCodeException>()),
      );
    });
  });

  group('OpenCodeClient.getSessionStatuses', () {
    testWidgets('returns status map', (tester) async {
      await client.createSession(input: SessionCreateInput(title: 'Status Test 1'));
      await client.createSession(input: SessionCreateInput(title: 'Status Test 2'));

      final statuses = await client.getSessionStatuses();

      expect(statuses, isA<Map<String, String>>());
      expect(statuses, isNotEmpty);
    });
  });

  group('OpenCodeClient.initSession and cancelSession', () {
    testWidgets('initializes session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Init Test'),
      );

      final result = await client.initSession(session.id);

      expect(result, isTrue);

      final updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.running));
    });

    testWidgets('cancels session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Cancel Test'),
      );

      await client.initSession(session.id);

      final result = await client.cancelSession(session.id);

      expect(result, isTrue);

      final updated = await client.getSession(session.id);
      expect(updated.status, equals(SessionStatus.idle));
    });

    testWidgets('initSession returns error for non-existent session', (tester) async {
      expect(
        () => client.initSession('non-existent-id'),
        throwsA(isA<OpenCodeException>()),
      );
    });

    testWidgets('cancelSession returns error for non-existent session', (tester) async {
      expect(
        () => client.cancelSession('non-existent-id'),
        throwsA(isA<OpenCodeException>()),
      );
    });
  });
}
