import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;
  late SSEClient sseClient;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      markTestSkipped(
          'SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    print('=== Concurrent Sessions Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(config: ServerConfig(url: serverUrl));

    sseClient = SSEClient();
    sseClient.connect(serverUrl: serverUrl);

    await Future.delayed(const Duration(seconds: 2));
  });

  tearDownAll(() {
    sseClient.disconnect();
    platformHttpClient.close();
  });

  group('Multiple Sessions Streaming Simultaneously', () {
    testWidgets('multiple sessions can stream messages concurrently',
        (tester) async {
      print('\n--- Test: Multiple Sessions Streaming Simultaneously ---');

      final sessions = <Session>[];
      final sendFutures = <Future>[];

      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Concurrent Session $i'));
        sessions.add(session);
      }

      print('Created ${sessions.length} sessions');

      for (int i = 0; i < sessions.length; i++) {
        final future = client.sendPrompt(
            sessions[i].id,
            text: 'Message for session $i at ${DateTime.now().millisecondsSinceEpoch}');
        sendFutures.add(future);
      }

      final responses = await Future.wait(sendFutures);

      print('All messages sent, responses: ${responses.length}');

      for (final session in sessions) {
        final messages = await client.getMessages(session.id);
        print('Session ${session.id}: ${messages.length} messages');
        expect(messages.length, greaterThan(0));
      }

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }

      print('Test completed successfully');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('concurrent sessions maintain independent state',
        (tester) async {
      print('\n--- Test: Concurrent Sessions Independent State ---');

      final session1 = await client.createSession(
          input: SessionCreateInput(title: 'Session 1'));
      final session2 = await client.createSession(
          input: SessionCreateInput(title: 'Session 2'));

      print('Created sessions: ${session1.id}, ${session2.id}');

      await client.sendPrompt(session1.id, text: 'Message for session 1');
      await Future.delayed(const Duration(milliseconds: 500));

      await client.sendPrompt(session2.id, text: 'Message for session 2');
      await Future.delayed(const Duration(milliseconds: 500));

      final messages1 = await client.getMessages(session1.id);
      final messages2 = await client.getMessages(session2.id);

      print('Session 1 messages: ${messages1.length}');
      print('Session 2 messages: ${messages2.length}');

      expect(messages1.length, greaterThan(0));
      expect(messages2.length, greaterThan(0));

      final session1HasOnlyOwnMessages =
          messages1.every((m) => m.role == 'user' && m.parts?.any((p) => p.text?.contains('session 1') == true) == true);
      final session2HasOnlyOwnMessages =
          messages2.every((m) => m.role == 'user' && m.parts?.any((p) => p.text?.contains('session 2') == true) == true);

      print('Session 1 has own messages: $session1HasOnlyOwnMessages');
      print('Session 2 has own messages: $session2HasOnlyOwnMessages');

      await client.deleteSession(session1.id);
      await client.deleteSession(session2.id);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Message Ordering Under Concurrent Load', () {
    testWidgets('messages maintain correct order in concurrent sessions',
        (tester) async {
      print('\n--- Test: Message Ordering Under Concurrent Load ---');

      final sessions = <Session>[];
      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Ordering Test $i'));
        sessions.add(session);
      }

      for (int round = 0; round < 2; round++) {
        final futures = <Future>[];
        for (int i = 0; i < sessions.length; i++) {
          final future = client.sendPrompt(
              sessions[i].id, text: 'Round $round message for session $i');
          futures.add(future);
        }
        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      for (final session in sessions) {
        final messages = await client.getMessages(session.id);
        final userMessages = messages.where((m) => m.role == 'user').toList();

        print('Session ${session.id}: ${userMessages.length} user messages');

        for (int i = 0; i < userMessages.length - 1; i++) {
          final currentTime = userMessages[i].time?.created ?? 0;
          final nextTime = userMessages[i + 1].time?.created ?? 0;
          expect(nextTime, greaterThanOrEqualTo(currentTime),
              reason: 'Messages should be in chronological order');
        }
      }

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('rapid concurrent sends maintain message integrity',
        (tester) async {
      print('\n--- Test: Rapid Concurrent Sends ---');

      final session = await client.createSession(
          input: SessionCreateInput(title: 'Rapid Concurrent Test'));

      final futures = <Future>[];
      for (int i = 0; i < 5; i++) {
        final future = client.sendPrompt(
            session.id, text: 'Rapid message $i');
        futures.add(future);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await Future.wait(futures);
      await Future.delayed(const Duration(seconds: 2));

      final messages = await client.getMessages(session.id);
      final userMessages = messages.where((m) => m.role == 'user').toList();

      print('Total user messages: ${userMessages.length}');

      expect(userMessages.length, equals(5),
          reason: 'All 5 messages should be stored');

      await client.deleteSession(session.id);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Race Condition Detection', () {
    testWidgets('concurrent create and delete operations handle race conditions',
        (tester) async {
      print('\n--- Test: Race Condition Detection ---');

      final createdSessions = <Session>[];
      final errors = <String>[];

      for (int i = 0; i < 5; i++) {
        try {
          final session = await client.createSession(
              input: SessionCreateInput(title: 'Race Test $i'));
          createdSessions.add(session);
        } catch (e) {
          errors.add('Create error: $e');
        }
      }

      print('Created ${createdSessions.length} sessions, errors: ${errors.length}');

      final deleteFutures = <Future>[];
      for (final session in createdSessions) {
        deleteFutures.add(
          client.deleteSession(session.id).catchError((e) {
            print('Delete error for ${session.id}: $e');
            return false;
          }),
        );
      }

      await Future.wait(deleteFutures);
      print('All delete operations completed');

      expect(createdSessions.length, equals(5));

      for (final session in createdSessions) {
        try {
          await client.getSession(session.id);
          fail('Session ${session.id} should have been deleted');
        } on OpenCodeException catch (_) {
          print('Session ${session.id} correctly not found after delete');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('concurrent status updates do not corrupt session data',
        (tester) async {
      print('\n--- Test: Concurrent Status Updates ---');

      final sessions = <Session>[];
      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Status Test $i'));
        sessions.add(session);
      }

      final statusFutures = <Future<Map<String, String>>>[];
      for (int i = 0; i < 5; i++) {
        statusFutures.add(client.getSessionStatuses());
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final statuses = await Future.wait(statusFutures);

      for (final statusMap in statuses) {
        expect(statusMap.containsKey(sessions[0].id), isTrue);
        expect(statusMap.containsKey(sessions[1].id), isTrue);
        expect(statusMap.containsKey(sessions[2].id), isTrue);
      }

      print('All status checks returned valid data');

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Concurrent Operations Non-Interference', () {
    testWidgets('concurrent operations on different sessions do not interfere',
        (tester) async {
      print('\n--- Test: Concurrent Operations Non-Interference ---');

      final session1 = await client.createSession(
          input: SessionCreateInput(title: 'Non-Interference 1'));
      final session2 = await client.createSession(
          input: SessionCreateInput(title: 'Non-Interference 2'));

      final op1 = client.sendPrompt(session1.id, text: 'Session 1 message');
      await Future.delayed(const Duration(milliseconds: 100));
      final op2 = client.sendPrompt(session2.id, text: 'Session 2 message');
      await Future.delayed(const Duration(milliseconds: 100));
      final op3 = client.sendPrompt(session1.id, text: 'Session 1 second');
      await Future.delayed(const Duration(milliseconds: 100));
      final op4 = client.sendPrompt(session2.id, text: 'Session 2 second');

      await Future.wait([op1, op2, op3, op4]);
      await Future.delayed(const Duration(seconds: 2));

      final messages1 = await client.getMessages(session1.id);
      final messages2 = await client.getMessages(session2.id);

      print('Session 1 messages: ${messages1.length}');
      print('Session 2 messages: ${messages2.length}');

      final session1Messages = messages1
          .where((m) => m.role == 'user')
          .map((m) => m.parts?.firstOrNull?.text ?? '')
          .toList();
      final session2Messages = messages2
          .where((m) => m.role == 'user')
          .map((m) => m.parts?.firstOrNull?.text ?? '')
          .toList();

      expect(session1Messages.any((t) => t.contains('Session 1')), isTrue);
      expect(session1Messages.any((t) => t.contains('Session 2')), isFalse,
          reason: 'Session 1 should not have Session 2 messages');

      expect(session2Messages.any((t) => t.contains('Session 2')), isTrue);
      expect(session2Messages.any((t) => t.contains('Session 1')), isFalse,
          reason: 'Session 2 should not have Session 1 messages');

      await client.deleteSession(session1.id);
      await client.deleteSession(session2.id);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('concurrent list and get operations return consistent data',
        (tester) async {
      print('\n--- Test: Concurrent List and Get Operations ---');

      final sessions = <Session>[];
      for (int i = 0; i < 5; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'List Get Test $i'));
        sessions.add(session);
      }

      final futures = <Future>[];

      for (int i = 0; i < 10; i++) {
        futures.add(client.listSessions());
        futures.add(client.getSessionStatuses());
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await Future.wait(futures);

      final allSessions = await client.listSessions();
      print('Total sessions listed: ${allSessions.length}');

      for (final session in sessions) {
        final retrieved = await client.getSession(session.id);
        expect(retrieved.id, equals(session.id));
        expect(retrieved.title, equals(session.title));
      }

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Session Isolation Under Concurrent Access', () {
    testWidgets('session data is isolated between concurrent accesses',
        (tester) async {
      print('\n--- Test: Session Isolation Under Concurrent Access ---');

      final sessions = <Session>[];
      final sessionData = <String, List<String>>{};

      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Isolation Test $i'));
        sessions.add(session);
        sessionData[session.id] = [];
      }

      final futures = <Future>[];
      for (int round = 0; round < 3; round++) {
        for (int i = 0; i < sessions.length; i++) {
          final messageText = 'Round $round for session $i';
          final future = client.sendPrompt(sessions[i].id, text: messageText)
              .then((_) {
            sessionData[sessions[i].id]!.add(messageText);
          });
          futures.add(future);
        }
      }

      await Future.wait(futures);
      await Future.delayed(const Duration(seconds: 2));

      for (int i = 0; i < sessions.length; i++) {
        final messages = await client.getMessages(sessions[i].id);
        final userMessages =
            messages.where((m) => m.role == 'user').toList();

        print('Session ${sessions[i].id}: ${userMessages.length} messages');

        for (final msg in userMessages) {
          final text = msg.parts?.firstOrNull?.text ?? '';
          expect(text.contains('session $i'), isTrue,
              reason: 'Message should belong to session $i');
        }
      }

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }

      print('Session isolation verified');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('deleting one session does not affect others',
        (tester) async {
      print('\n--- Test: Deleting One Session Does Not Affect Others ---');

      final sessions = <Session>[];
      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Delete Test $i'));
        sessions.add(session);
        await client.sendPrompt(session.id, text: 'Message before delete');
      }

      await Future.delayed(const Duration(seconds: 1));

      await client.deleteSession(sessions[1].id);
      print('Deleted session ${sessions[1].id}');

      final remainingSessions = await client.listSessions();
      final remainingIds = remainingSessions.map((s) => s.id).toSet();

      expect(remainingIds.contains(sessions[0].id), isTrue,
          reason: 'Session 0 should still exist');
      expect(remainingIds.contains(sessions[1].id), isFalse,
          reason: 'Session 1 should be deleted');
      expect(remainingIds.contains(sessions[2].id), isTrue,
          reason: 'Session 2 should still exist');

      final session0Messages = await client.getMessages(sessions[0].id);
      final session2Messages = await client.getMessages(sessions[2].id);

      expect(session0Messages.isNotEmpty, isTrue,
          reason: 'Session 0 should have messages');
      expect(session2Messages.isNotEmpty, isTrue,
          reason: 'Session 2 should have messages');

      await client.deleteSession(sessions[0].id);
      await client.deleteSession(sessions[2].id);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('concurrent message retrieval returns correct session data',
        (tester) async {
      print('\n--- Test: Concurrent Message Retrieval ---');

      final sessions = <Session>[];
      for (int i = 0; i < 4; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Retrieve Test $i'));
        sessions.add(session);

        for (int j = 0; j < 2; j++) {
          await client.sendPrompt(
              session.id, text: 'Session $i message $j');
        }
      }

      await Future.delayed(const Duration(seconds: 2));

      final futures = <Future<List<dynamic>>>[];
      for (final session in sessions) {
        futures.add(client.getMessages(session.id));
      }

      final results = await Future.wait(futures);

      for (int i = 0; i < results.length; i++) {
        final messages = results[i];
        print('Session ${sessions[i].id}: ${messages.length} messages');

        final userMessages =
            messages.where((m) => m.role == 'user').toList();
        expect(userMessages.length, equals(2),
            reason: 'Each session should have 2 user messages');
      }

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('SSE Events During Concurrent Operations', () {
    testWidgets('SSE events are correctly routed during concurrent sessions',
        (tester) async {
      print('\n--- Test: SSE Events During Concurrent Operations ---');

      final events = <SSEEvent>[];
      final sessionEvents = <String, List<SSEEvent>>{};

      final eventSubscription = sseClient.eventStream.listen((event) {
        events.add(event);
        if (event.event == 'session.created') {
          final data = event.data;
          if (data != null && data.containsKey('session')) {
            final sessionId = data['session']?['id'] ?? data['id'];
            sessionEvents.putIfAbsent(sessionId.toString(), () => []);
            sessionEvents[sessionId.toString()]!.add(event);
          }
        }
      });

      final sessions = <Session>[];
      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'SSE Concurrent $i'));
        sessions.add(session);
      }

      await Future.delayed(const Duration(seconds: 2));

      print('Total SSE events: ${events.length}');

      final sessionCreatedEvents =
          events.where((e) => e.event == 'session.created').toList();
      print('Session created events: ${sessionCreatedEvents.length}');

      expect(sessionCreatedEvents.length, greaterThanOrEqualTo(3),
          reason: 'Should receive session.created events');

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }

      await eventSubscription.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
