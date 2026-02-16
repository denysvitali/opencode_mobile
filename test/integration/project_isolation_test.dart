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
      markTestSkipped(
          'SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    print('=== Project Isolation Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('Project Session Isolation', () {
    testWidgets('sessions in project A are not visible in project B',
        (tester) async {
      const projectA = '/project-a';
      const projectB = '/project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Project A Session'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Project B Session'),
      );

      try {
        final sessionsInA = await client.listSessions(directory: projectA);
        final sessionsInB = await client.listSessions(directory: projectB);

        final idsInA = sessionsInA.map((s) => s.id).toList();
        final idsInB = sessionsInB.map((s) => s.id).toList();

        expect(idsInA, contains(sessionA.id));
        expect(idsInB, contains(sessionB.id));

        expect(idsInA, isNot(contains(sessionB.id)),
            reason: 'Project B session should not appear in Project A list');
        expect(idsInB, isNot(contains(sessionA.id)),
            reason: 'Project A session should not appear in Project B list');
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });

    testWidgets('getSession respects project boundaries', (tester) async {
      const projectA = '/project-a';
      const projectB = '/project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Get Session in A'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Get Session in B'),
      );

      try {
        final fetchedA = await client.getSession(sessionA.id, directory: projectA);
        final fetchedB = await client.getSession(sessionB.id, directory: projectB);

        expect(fetchedA.title, equals('Get Session in A'));
        expect(fetchedB.title, equals('Get Session in B'));
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });
  });

  group('Project Message Isolation', () {
    testWidgets('messages in project A do not appear in project B', (tester) async {
      const projectA = '/msg-project-a';
      const projectB = '/msg-project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Message Test A'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Message Test B'),
      );

      try {
        await client.sendPrompt(
          sessionA.id,
          text: 'Message for Project A',
          directory: projectA,
        );

        await client.sendPrompt(
          sessionB.id,
          text: 'Message for Project B',
          directory: projectB,
        );

        final messagesA = await client.getMessages(sessionA.id, directory: projectA);
        final messagesB = await client.getMessages(sessionB.id, directory: projectB);

        expect(messagesA.length, greaterThanOrEqualTo(2));
        expect(messagesB.length, greaterThanOrEqualTo(2));

        final textA = messagesA.map((m) => m.parts.map((p) => p.text).join()).join();
        final textB = messagesB.map((m) => m.parts.map((p) => p.text).join()).join();

        expect(textA, contains('Message for Project A'));
        expect(textA, isNot(contains('Message for Project B')),
            reason: 'Project B message should not appear in Project A');

        expect(textB, contains('Message for Project B'));
        expect(textB, isNot(contains('Message for Project A')),
            reason: 'Project A message should not appear in Project B');
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });

    testWidgets('sending message to wrong project fails or is isolated',
        (tester) async {
      const projectA = '/isolated-project-a';
      const projectB = '/isolated-project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Isolation Test A'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Isolation Test B'),
      );

      try {
        await client.sendPrompt(
          sessionA.id,
          text: 'Message in correct project',
          directory: projectA,
        );

        final messagesInA = await client.getMessages(sessionA.id, directory: projectA);
        final messagesInB = await client.getMessages(sessionB.id, directory: projectB);

        expect(messagesInA.length, greaterThanOrEqualTo(2));
        expect(messagesInB.length, equals(0),
            reason: 'Messages should not leak between projects');
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });
  });

  group('Project Configuration Isolation', () {
    testWidgets('config in project A is separate from project B', (tester) async {
      const projectA = '/config-project-a';
      const projectB = '/config-project-b';

      final configA = await client.getConfig(directory: projectA);
      final configB = await client.getConfig(directory: projectB);

      expect(configA, isNotNull);
      expect(configB, isNotNull);
    });

    testWidgets('providers in project A is separate from project B', (tester) async {
      const projectA = '/provider-project-a';
      const projectB = '/provider-project-b';

      final providersA = await client.getConfigProviders(directory: projectA);
      final providersB = await client.getConfigProviders(directory: projectB);

      expect(providersA, isNotNull);
      expect(providersB, isNotNull);
    });
  });

  group('Project Status Isolation', () {
    testWidgets('session status in project A is not visible in project B',
        (tester) async {
      const projectA = '/status-project-a';
          const projectB = '/status-project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Status Test A'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Status Test B'),
      );

      try {
        await client.initSession(sessionA.id, directory: projectA);

        final statusesA = await client.getSessionStatuses(directory: projectA);
        final statusesB = await client.getSessionStatuses(directory: projectB);

        if (statusesA.containsKey(sessionA.id)) {
          expect(statusesA[sessionA.id], equals('running'));
        }

        if (statusesB.containsKey(sessionA.id)) {
          fail('Session A status should not appear in project B');
        }

        expect(statusesB.containsKey(sessionA.id), isFalse,
            reason: 'Project A session should not be in Project B status');
      } finally {
        await client.cancelSession(sessionA.id, directory: projectA);
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });
  });

  group('Project List Filtering', () {
    testWidgets('listSessions filters by project directory', (tester) async {
      const projectA = '/filter-project-a';
      const projectB = '/filter-project-b';

      final sessionA1 = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Filter A1'),
      );
      final sessionA2 = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Filter A2'),
      );

      final sessionB1 = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Filter B1'),
      );

      try {
        final sessionsA = await client.listSessions(directory: projectA);
        final sessionsB = await client.listSessions(directory: projectB);

        final titlesA = sessionsA.map((s) => s.title).toList();
        final titlesB = sessionsB.map((s) => s.title).toList();

        expect(titlesA, contains('Filter A1'));
        expect(titlesA, contains('Filter A2'));
        expect(titlesA, isNot(contains('Filter B1')),
            reason: 'Project B session should not appear in Project A list');

        expect(titlesB, contains('Filter B1'));
        expect(titlesB, isNot(contains('Filter A1')),
            reason: 'Project A sessions should not appear in Project B list');
      } finally {
        await client.deleteSession(sessionA1.id);
        await client.deleteSession(sessionA2.id);
        await client.deleteSession(sessionB1.id);
      }
    });

    testWidgets('search is scoped to project directory', (tester) async {
      const projectA = '/search-project-a';
      const projectB = '/search-project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'UniqueSearchA'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'UniqueSearchB'),
      );

      try {
        final searchInA = await client.listSessions(
          directory: projectA,
          search: 'UniqueSearch',
        );

        final titlesA = searchInA.map((s) => s.title).toList();
        expect(titlesA, contains('UniqueSearchA'));
        expect(titlesA, isNot(contains('UniqueSearchB')),
            reason: 'Search should be scoped to project A');
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });
  });

  group('Project Delete Isolation', () {
    testWidgets('deleting session in project A does not affect project B',
        (tester) async {
      const projectA = '/delete-project-a';
      const projectB = '/delete-project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Delete Me A'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Keep Me B'),
      );

      await client.deleteSession(sessionA.id);

      final sessionsInA = await client.listSessions(directory: projectA);
      final sessionsInB = await client.listSessions(directory: projectB);

      final idsA = sessionsInA.map((s) => s.id).toList();
      final idsB = sessionsInB.map((s) => s.id).toList();

      expect(idsA, isNot(contains(sessionA.id)),
          reason: 'Session A should be deleted');
      expect(idsB, contains(sessionB.id),
          reason: 'Session B should still exist');

      await client.deleteSession(sessionB.id);
    });
  });

  group('Project Update Isolation', () {
    testWidgets('updating session in project A does not affect project B',
        (tester) async {
      const projectA = '/update-project-a';
      const projectB = '/update-project-b';

      final sessionA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Original A'),
      );

      final sessionB = await client.createSession(
        directory: projectB,
        input: SessionCreateInput(title: 'Original B'),
      );

      try {
        await client.updateSession(
          sessionA.id,
          SessionUpdateInput(title: 'Updated A'),
          directory: projectA,
        );

        final fetchedA = await client.getSession(sessionA.id, directory: projectA);
        final fetchedB = await client.getSession(sessionB.id, directory: projectB);

        expect(fetchedA.title, equals('Updated A'));
        expect(fetchedB.title, equals('Original B'),
            reason: 'Session B should not be affected by update in A');
      } finally {
        await client.deleteSession(sessionA.id);
        await client.deleteSession(sessionB.id);
      }
    });
  });

  group('Project Children Isolation', () {
    testWidgets('session children are scoped to project', (tester) async {
      const projectA = '/children-project-a';

      final parentA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(title: 'Parent A'),
      );

      final childA = await client.createSession(
        directory: projectA,
        input: SessionCreateInput(
          title: 'Child A',
          parentID: parentA.id,
        ),
      );

      try {
        final childrenInA = await client.getSessionChildren(
          parentA.id,
          directory: projectA,
        );

        expect(childrenInA, isNotEmpty);
        expect(childrenInA.any((c) => c.id == childA.id), isTrue,
            reason: 'Child should be in parent A\'s children list');
      } finally {
        await client.deleteSession(childA.id);
        await client.deleteSession(parentA.id);
      }
    });
  });
}
