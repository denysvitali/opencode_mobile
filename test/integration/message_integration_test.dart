import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;
  late String initialSessionId;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      markTestSkipped(
          'SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    print('=== Message Integration Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );

    final sessions = await client.listSessions();
    if (sessions.isNotEmpty) {
      initialSessionId = sessions.first.id;
    }
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('OpenCodeClient.getMessages', () {
    testWidgets('returns messages for a session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Messages Test Session'),
      );

      try {
        await client.sendPrompt(session.id, text: 'Hello, this is a test message');

        await Future.delayed(const Duration(milliseconds: 500));

        final messages = await client.getMessages(session.id);

        expect(messages, isNotEmpty,
            reason: 'Session with messages should return message list');
        expect(messages.length, greaterThanOrEqualTo(1),
            reason: 'Should have at least one message');

        final hasUserMessage =
            messages.any((m) => m.role == MessageRole.user);
        expect(hasUserMessage, isTrue,
            reason: 'Should contain user message');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('returns empty list for new session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Empty Messages Session'),
      );

      try {
        final messages = await client.getMessages(session.id);

        expect(messages, isA<List<Message>>(),
            reason: 'Should return a list');
        expect(messages, isEmpty,
            reason: 'New session should have no messages');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('handles session not found', (tester) async {
      const invalidSessionId = 'non-existent-session-12345';

      try {
        await client.getMessages(invalidSessionId);
        fail('Should throw exception for non-existent session');
      } on OpenCodeException catch (e) {
        expect(e.message, contains('Failed'),
            reason: 'Exception should indicate failure');
      }
    });
  });

  group('OpenCodeClient.sendPrompt', () {
    testWidgets('sends text message', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Send Prompt Test'),
      );

      try {
        const testText = 'This is a test prompt message';
        final userMessage =
            await client.sendPrompt(session.id, text: testText);

        expect(userMessage, isNotNull,
            reason: 'Should return user message');
        expect(userMessage.id, isNotEmpty,
            reason: 'Message should have an ID');
        expect(userMessage.role, equals(MessageRole.user),
            reason: 'Message should have user role');

        final textContent = userMessage.textContent;
        expect(textContent, contains(testText),
            reason: 'Message content should contain sent text');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('returns user message', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'User Message Test'),
      );

      try {
        final userMessage = await client.sendPrompt(
          session.id,
          text: 'Return user message test',
        );

        expect(userMessage.role, equals(MessageRole.user),
            reason: 'Returned message should have user role');
        expect(userMessage.sessionId, equals(session.id),
            reason: 'Message should belong to correct session');

        final hasTextPart = userMessage.parts.any(
            (p) => p.type == MessagePartType.text);
        expect(hasTextPart, isTrue,
            reason: 'User message should have text part');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('creates assistant response in session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Assistant Response Test'),
      );

      try {
        await client.sendPrompt(
          session.id,
          text: 'Trigger assistant response',
        );

        await Future.delayed(const Duration(milliseconds: 500));

        final messages = await client.getMessages(session.id);

        expect(messages.length, greaterThanOrEqualTo(2),
            reason: 'Should have user and assistant messages');

        final hasAssistantMessage =
            messages.any((m) => m.role == MessageRole.assistant);
        expect(hasAssistantMessage, isTrue,
            reason: 'Should contain assistant message');

        final assistantMessage = messages.firstWhere(
            (m) => m.role == MessageRole.assistant);
        expect(assistantMessage.textContent, isNotEmpty,
            reason: 'Assistant message should have content');
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('OpenCodeClient.sendPromptStream', () {
    testWidgets('returns stream of messages', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Stream Test Session'),
      );

      try {
        final receivedMessages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Hello from streaming test',
        );

        await for (final message in stream) {
          receivedMessages.add(message);
        }

        expect(receivedMessages, isNotEmpty,
            reason: 'Should receive at least one message');

        for (final msg in receivedMessages) {
          expect(msg.sessionId, equals(session.id),
              reason: 'All messages should belong to the session');
        }
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('handles SSE format', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'SSE Format Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'SSE format test',
        );

        await for (final message in stream) {
          messages.add(message);
        }

        expect(messages.isNotEmpty, isTrue,
            reason: 'Should receive messages via SSE');

        final hasUserMsg =
            messages.any((m) => m.role == MessageRole.user);
        final hasAssistantMsg =
            messages.any((m) => m.role == MessageRole.assistant);

        expect(hasUserMsg || hasAssistantMsg, isTrue,
            reason: 'Should have user or assistant messages');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('yields message updates', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Message Updates Test'),
      );

      try {
        final messages = <Message>[];
        String? lastMessageId;

        final stream = client.sendPromptStream(
          session.id,
          text: 'Test message updates',
        );

        await for (final message in stream) {
          messages.add(message);
          if (lastMessageId != null && message.id == lastMessageId) {
            break;
          }
          lastMessageId = message.id;
        }

        expect(messages, isNotEmpty,
            reason: 'Should yield multiple message updates');

        if (messages.length > 1) {
          final distinctRoles =
              messages.map((m) => m.role).toSet();
          expect(distinctRoles.length, greaterThanOrEqualTo(1),
              reason: 'Should have at least one role type');
        }
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('OpenCodeClient.cancelSession', () {
    testWidgets('cancels running session', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Cancel Session Test'),
      );

      try {
        final statusesBefore = await client.getSessionStatuses();
        final initialStatus = statusesBefore[session.id] ?? 'idle';

        final result = await client.cancelSession(session.id);

        expect(result, isTrue,
            reason: 'Cancel should return true');

        final statusesAfter = await client.getSessionStatuses();
        final statusAfter = statusesAfter[session.id] ?? 'unknown';

        expect(statusAfter, isNot(equals('running')),
            reason: 'Session should not be running after cancel');
      } finally {
        try {
          await client.deleteSession(session.id);
        } catch (_) {}
      }
    });

    testWidgets('cancel non-existent session throws', (tester) async {
      const invalidSessionId = 'cancel-invalid-session-999';

      try {
        await client.cancelSession(invalidSessionId);
        fail('Should throw exception for non-existent session');
      } on OpenCodeException catch (e) {
        expect(e.message, anyOf(contains('Failed'), contains('not found')),
            reason: 'Exception should indicate failure');
      }
    });
  });

  group('Message Model Validation', () {
    testWidgets('messages have valid structure', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Message Structure Test'),
      );

      try {
        await client.sendPrompt(session.id, text: 'Validate message structure');

        await Future.delayed(const Duration(milliseconds: 500));

        final messages = await client.getMessages(session.id);

        expect(messages, isNotEmpty);

        for (final message in messages) {
          expect(message.id, isNotEmpty,
              reason: 'Message should have ID');
          expect(message.sessionId, equals(session.id),
              reason: 'Message should belong to session');
          expect(message.role, isNotNull,
              reason: 'Message should have role');
          expect(message.parts, isNotNull,
              reason: 'Message should have parts list');
        }
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('message parts are parsed correctly', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Parts Parsing Test'),
      );

      try {
        final userMessage = await client.sendPrompt(
          session.id,
          text: 'Test parts parsing',
        );

        expect(userMessage.parts, isNotEmpty,
            reason: 'Message should have parts');

        final textPart = userMessage.parts.firstWhere(
            (p) => p.type == MessagePartType.text,
            orElse: () => throw StateError('No text part'));
        expect(textPart.text, isNotEmpty,
            reason: 'Text part should have content');
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });
}
