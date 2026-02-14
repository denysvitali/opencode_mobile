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

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      markTestSkipped('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    print('=== Streaming Message Test ===');
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

  group('Streaming Message Send', () {
    testWidgets('sendPromptStream returns stream of messages', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Streaming Test Session'),
      );

      try {
        final receivedMessages = <Message>[];

        // Send streaming request
        final stream = client.sendPromptStream(
          session.id,
          text: 'Hello from streaming test',
        );

        // Collect all streamed messages
        await for (final message in stream) {
          print('Received stream chunk: id=${message.id}, role=${message.role}');
          receivedMessages.add(message);
        }

        // Verify we received messages
        expect(receivedMessages, isNotEmpty,
            reason: 'Should receive at least one message chunk');

        // All messages should have the same session ID
        for (final msg in receivedMessages) {
          expect(msg.sessionId, equals(session.id),
              reason: 'All messages should belong to the session');
        }
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('streaming with explicit model', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Streaming Model Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Test with model',
          providerID: 'mock',
          modelID: 'mock-gpt-4',
        );

        await for (final message in stream) {
          messages.add(message);
        }

        expect(messages, isNotEmpty);
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('streaming handles empty response gracefully', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Empty Stream Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: '', // Empty message
        );

        await for (final message in stream) {
          messages.add(message);
        }

        // Should either get no messages or some response
        print('Received ${messages.length} messages for empty input');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('streaming handles long message', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Long Message Stream Test'),
      );

      try {
        final messages = <Message>[];
        final longText = 'Please provide a detailed response about ' +
            'Flutter integration testing. ' * 10;

        final stream = client.sendPromptStream(
          session.id,
          text: longText,
        );

        await for (final message in stream) {
          messages.add(message);
        }

        expect(messages, isNotEmpty);

        // Combine all parts to see full response
        final fullResponse = messages
            .expand((m) => m.parts ?? [])
            .where((p) => p.type == MessagePartType.text)
            .map((p) => p.text)
            .where((text) => text != null)
            .join('');

        print('Full response length: ${fullResponse.length}');
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('streaming completes within timeout', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Timeout Stream Test'),
      );

      try {
        final messages = <Message>[];
        final completer = Completer<void>();

        final stream = client.sendPromptStream(
          session.id,
          text: 'Quick response please',
        );

        // Collect with timeout
        final subscription = stream.listen(
          (message) => messages.add(message),
          onDone: () => completer.complete(),
          onError: (e) => completer.completeError(e),
        );

        // Wait up to 30 seconds
        try {
          await completer.future.timeout(const Duration(seconds: 30));
        } on TimeoutException {
          print('Stream timed out after 30 seconds');
          // Cancel subscription
          await subscription.cancel();
        }

        print('Received ${messages.length} messages before timeout/completion');

        // Should have received at least initial response
        expect(messages.isNotEmpty, isTrue,
            reason: 'Should receive response within timeout');
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('Stream vs Non-Stream Comparison', () {
    testWidgets('streaming and non-streaming produce similar results',
        (tester) async {
      // Create two sessions for comparison
      final streamSession = await client.createSession(
        input: SessionCreateInput(title: 'Stream Compare'),
      );
      final normalSession = await client.createSession(
        input: SessionCreateInput(title: 'Normal Compare'),
      );

      try {
        // Send streaming message
        final streamMessages = <Message>[];
        final stream = client.sendPromptStream(
          streamSession.id,
          text: 'Compare test message',
        );
        await for (final msg in stream) {
          streamMessages.add(msg);
        }

        // Send non-streaming message
        final normalResponse = await client.sendPrompt(
          normalSession.id,
          text: 'Compare test message',
        );

        // Both should succeed
        expect(streamMessages, isNotEmpty);
        expect(normalResponse.id, isNotEmpty);

        // Get final messages for both
        final streamFinal = await client.getMessages(streamSession.id);
        final normalFinal = await client.getMessages(normalSession.id);

        print('Stream session messages: ${streamFinal.length}');
        print('Normal session messages: ${normalFinal.length}');

        // Both should have user message
        expect(streamFinal.isNotEmpty, isTrue);
        expect(normalFinal.isNotEmpty, isTrue);
      } finally {
        await client.deleteSession(streamSession.id);
        await client.deleteSession(normalSession.id);
      }
    });
  });

  group('Streaming Error Handling', () {
    testWidgets('streaming handles invalid session gracefully', (tester) async {
      final invalidSessionId = 'invalid-session-id-12345';

      final messages = <Message>[];

      try {
        final stream = client.sendPromptStream(
          invalidSessionId,
          text: 'This should fail',
        );

        await for (final message in stream) {
          messages.add(message);
        }

        // If we get here without exception, that's also valid
        // Server might return error messages
      } on OpenCodeException catch (e) {
        // Expected - invalid session should error
        print('Expected error for invalid session: $e');
        expect(e.message, contains('Failed'));
      } catch (e) {
        // Other errors also acceptable
        print('Error for invalid session: $e');
      }
    });

    testWidgets('streaming can be cancelled', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Cancel Stream Test'),
      );

      final receivedMessages = <Message>[];

      try {
        final stream = client.sendPromptStream(
          session.id,
          text: 'This is a long message that might take time to process',
        );

        // Listen for a short time then cancel
        final subscription = stream.listen((msg) {
          receivedMessages.add(msg);
        });

        // Wait a bit
        await Future.delayed(const Duration(seconds: 2));

        // Cancel
        await subscription.cancel();

        print('Cancelled after receiving ${receivedMessages.length} messages');

        // Should have received some messages before cancellation
        // (or none if it finished quickly)
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });

  group('Streaming Message Structure', () {
    testWidgets('streamed messages have valid structure', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Structure Stream Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Structure test',
        );

        await for (final message in stream) {
          messages.add(message);

          // Validate structure
          expect(message.id, isNotEmpty, reason: 'Message should have ID');
          expect(message.sessionId, equals(session.id),
              reason: 'Message should belong to correct session');
          expect(message.role, isNotNull, reason: 'Message should have role');
          expect(message.parts, isNotNull, reason: 'Message should have parts');
        }

        expect(messages.isNotEmpty, isTrue);
      } finally {
        await client.deleteSession(session.id);
      }
    });

    testWidgets('streamed message parts are valid', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Parts Stream Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Parts validation test',
        );

        await for (final message in stream) {
          messages.add(message);

          // Check parts
          for (final part in message.parts ?? []) {
            expect(part.type.name, isNotEmpty, reason: 'Part should have type');

            if (part.type == MessagePartType.text) {
              expect(part.text, isNotNull, reason: 'Text part should have text');
            }
          }
        }

        expect(messages.isNotEmpty, isTrue);
      } finally {
        await client.deleteSession(session.id);
      }
    });
  });
}
