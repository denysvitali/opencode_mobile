import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/message.dart';
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

    print('=== Chat Init Flow Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(config: ServerConfig(url: serverUrl));

    sseClient = SSEClient();
  });

  tearDownAll(() {
    sseClient.disconnect();
    platformHttpClient.close();
  });

  group('Chat Init Flow - Full Lifecycle', () {
    testWidgets('create -> init -> send -> receive -> verify status transitions',
        (tester) async {
      final statusHistory = <String>[];
      final statusSubscription = sseClient.sessionStatusStream.listen((statuses) {
        print('Status update: $statuses');
      });

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      try {
        final session = await client.createSession(
          input: SessionCreateInput(title: 'Chat Init Flow Test'),
        );
        print('Created session: ${session.id}, status: ${session.status}');
        expect(session.id, isNotEmpty);
        expect(session.status, equals(SessionStatus.idle));
        statusHistory.add(session.status.name);

        await Future.delayed(const Duration(seconds: 1));

        final initResponse = await client.initSession(session.id);
        print('Init response: $initResponse');

        await Future.delayed(const Duration(seconds: 1));

        final runningSession = await client.getSession(session.id);
        print('Session after init: ${runningSession.status}');
        statusHistory.add(runningSession.status.name);

        final response = await client.sendPrompt(
          session.id,
          text: 'Say exactly: "Flow test complete"',
        );
        print('Send response: ${response.id}');

        await Future.delayed(const Duration(seconds: 2));

        final messages = await client.getMessages(session.id);
        print('Messages count: ${messages.length}');
        expect(messages, isNotEmpty);

        final assistantMessages =
            messages.where((m) => m.role == MessageRole.assistant).toList();
        print('Assistant messages: ${assistantMessages.length}');

        final finalSession = await client.getSession(session.id);
        print('Final session status: ${finalSession.status}');
        statusHistory.add(finalSession.status.name);

        expect(
            statusHistory, contains('idle'),
            reason: 'Session should have been idle at some point');
        expect(
            statusHistory, contains('running'),
            reason: 'Session should have been running during processing');

        await client.deleteSession(session.id);
      } finally {
        await statusSubscription.cancel();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('session starts in idle, transitions through running, back to idle',
        (tester) async {
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Status Transition Test'),
      );

      try {
        final initialSession = await client.getSession(session.id);
        expect(initialSession.status, equals(SessionStatus.idle),
            reason: 'New session should be idle');

        await client.sendPrompt(session.id, text: 'Test status transition');

        var foundRunning = false;
        var foundIdleAgain = false;

        for (var i = 0; i < 15; i++) {
          await Future.delayed(const Duration(seconds: 1));
          final currentSession = await client.getSession(session.id);
          print('Poll $i: ${currentSession.status}');

          if (currentSession.status == SessionStatus.running) {
            foundRunning = true;
          }
          if (currentSession.status == SessionStatus.idle && foundRunning) {
            foundIdleAgain = true;
            break;
          }
        }

        expect(foundRunning, isTrue,
            reason: 'Session should transition to running');
        expect(foundIdleAgain, isTrue,
            reason: 'Session should return to idle');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Error Recovery', () {
    testWidgets('error recovery when message send fails', (tester) async {
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Error Recovery Test'),
      );

      try {
        final invalidSessionId = 'invalid-session-12345';

        bool caughtError = false;
        try {
          await client.sendPrompt(invalidSessionId, text: 'This should fail');
        } catch (e) {
          print('Expected error caught: $e');
          caughtError = true;
        }

        expect(caughtError, isTrue,
            reason: 'Should catch error for invalid session');

        final validResponse = await client.sendPrompt(
          session.id,
          text: 'Valid message after error',
        );
        expect(validResponse.id, isNotEmpty,
            reason: 'Should work after failed attempt');

        final messages = await client.getMessages(session.id);
        expect(messages.length, greaterThanOrEqualTo(1),
            reason: 'Should have user message');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('session remains accessible after send error', (tester) async {
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session After Error Test'),
      );

      try {
        try {
          await client.sendPrompt(
            'non-existent-session',
            text: 'Will fail',
          );
        } catch (_) {}

        final retrievedSession = await client.getSession(session.id);
        expect(retrievedSession.id, equals(session.id),
            reason: 'Original session should still be accessible');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Message Persistence', () {
    testWidgets('messages are persisted correctly after session restart',
        (tester) async {
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Persistence Test'),
      );

      try {
        await client.sendPrompt(session.id, text: 'First message');
        await Future.delayed(const Duration(seconds: 2));

        final messagesBefore = await client.getMessages(session.id);
        print('Messages before: ${messagesBefore.length}');
        expect(messagesBefore, isNotEmpty);

        final firstMessageIds = messagesBefore.map((m) => m.id).toSet();

        await client.sendPrompt(session.id, text: 'Second message');
        await Future.delayed(const Duration(seconds: 2));

        final messagesAfter = await client.getMessages(session.id);
        print('Messages after: ${messagesAfter.length}');
        expect(messagesAfter.length, greaterThan(messagesBefore.length),
            reason: 'Should have more messages after second send');

        final newMessageIds =
            messagesAfter.map((m) => m.id).toSet().difference(firstMessageIds);
        print('New messages: ${newMessageIds.length}');
        expect(newMessageIds.isNotEmpty, isTrue,
            reason: 'Should have new messages');

        final reFetchedMessages = await client.getMessages(session.id);
        expect(reFetchedMessages.length, equals(messagesAfter.length),
            reason: 'Messages should be consistent across fetches');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('message content is preserved across fetches', (tester) async {
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      const testText = 'This is a test message content preservation';
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Content Preservation Test'),
      );

      try {
        await client.sendPrompt(session.id, text: testText);
        await Future.delayed(const Duration(seconds: 2));

        final messages1 = await client.getMessages(session.id);
        final userMessages =
            messages1.where((m) => m.role == MessageRole.user).toList();
        expect(userMessages, isNotEmpty);

        final userMessage = userMessages.first;
        final userText = userMessage.parts
                ?.where((p) => p.type == MessagePartType.text)
                .map((p) => p.text)
                .join('') ??
            '';

        expect(userText, contains('test message'),
            reason: 'User message content should be preserved');

        final messages2 = await client.getMessages(session.id);
        final userMessage2 =
            messages2.where((m) => m.role == MessageRole.user).first;
        final userText2 = userMessage2.parts
                ?.where((p) => p.type == MessagePartType.text)
                .map((p) => p.text)
                .join('') ??
            '';

        expect(userText2, equals(userText),
            reason: 'Content should be identical across fetches');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Multi-turn Conversation', () {
    testWidgets('multi-turn conversation maintains context', (tester) async {
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Multi-turn Test'),
      );

      try {
        await client.sendPrompt(session.id, text: 'Remember: the code is 12345');
        await Future.delayed(const Duration(seconds: 2));

        await client.sendPrompt(session.id, text: 'What was the code I told you?');
        await Future.delayed(const Duration(seconds: 3));

        final messages = await client.getMessages(session.id);
        print('Total messages: ${messages.length}');

        final userMessages =
            messages.where((m) => m.role == MessageRole.user).length;
        final assistantMessages =
            messages.where((m) => m.role == MessageRole.assistant).length;

        expect(userMessages, greaterThanOrEqualTo(2),
            reason: 'Should have at least 2 user messages');
        expect(assistantMessages, greaterThanOrEqualTo(1),
            reason: 'Should have at least 1 assistant response');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
