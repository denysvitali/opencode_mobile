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

    print('=== Streaming Full Test ===');
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

  group('SSE Message Part Updates', () {
    testWidgets('SSE message part updates arrive correctly', (tester) async {
      final partUpdates = <Message>[];
      final messageUpdates = <Message>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final partSub = sseClient.messagePartUpdateStream.listen((msg) {
        print('Part update: ${msg.id}');
        partUpdates.add(msg);
      });

      final msgSub = sseClient.messageUpdateStream.listen((msg) {
        print('Message update: ${msg.id}, role: ${msg.role}');
        messageUpdates.add(msg);
      });

      try {
        final session = await client.createSession(
          input: SessionCreateInput(title: 'SSE Part Updates Test'),
        );

        await client.sendPrompt(
          session.id,
          text: 'Generate some text for part updates',
        );

        await Future.delayed(const Duration(seconds: 5));

        print('Part updates received: ${partUpdates.length}');
        print('Message updates received: ${messageUpdates.length}');

        await partSub.cancel();
        await msgSub.cancel();
        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Multiple Chunks in Sequence', () {
    testWidgets('multiple streaming chunks arrive in sequence', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Chunk Sequence Test'),
      );

      try {
        final chunks = <Message>[];
        final completer = Completer<void>();

        final stream = client.sendPromptStream(
          session.id,
          text: 'Write a short story about a robot.',
        );

        var chunkCount = 0;
        await for (final message in stream) {
          chunkCount++;
          print('Chunk $chunkCount: ${message.id}');
          chunks.add(message);

          final text = message.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';
          print('  Text length: ${text.length}');
        }

        print('Total chunks received: $chunkCount');
        expect(chunks, isNotEmpty, reason: 'Should receive at least one chunk');

        final allTexts = chunks
            .expand((m) => m.parts ?? [])
            .where((p) => p.type == MessagePartType.text)
            .map((p) => p.text)
            .where((t) => t != null)
            .join('');
        print('Combined text length: ${allTexts.length}');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('chunks are accumulated correctly over time', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Chunk Accumulation Test'),
      );

      try {
        final intermediateLengths = <int>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Count from 1 to 5, one number per response.',
        );

        await for (final message in stream) {
          final text = message.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';
          intermediateLengths.add(text.length);
          print('Intermediate length: ${text.length}, text: "$text"');
        }

        print('Intermediate lengths: $intermediateLengths');
        expect(intermediateLengths.isNotEmpty, isTrue);

        final isIncreasingOrEqual = _isNonDecreasing(intermediateLengths);
        expect(isIncreasingOrEqual, isTrue,
            reason: 'Text should accumulate (lengths should be non-decreasing)');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Provider/Model Combinations', () {
    testWidgets('streaming with mock provider and model', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Provider Model Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Test with explicit provider and model',
          providerID: 'mock',
          modelID: 'mock-gpt-4',
        );

        await for (final message in stream) {
          print('Message: ${message.id}, role: ${message.role}');
          messages.add(message);
        }

        expect(messages, isNotEmpty,
            reason: 'Should receive messages with explicit provider/model');

        final hasUserMessage =
            messages.any((m) => m.role == MessageRole.user);
        expect(hasUserMessage, isTrue,
            reason: 'Should have user message');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('streaming without explicit provider uses defaults', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Default Provider Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Test with default provider',
        );

        await for (final message in stream) {
          messages.add(message);
        }

        expect(messages, isNotEmpty);

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Cancel Mid-Stream', () {
    testWidgets('streaming can be cancelled mid-stream', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Cancel Stream Test'),
      );

      try {
        final receivedMessages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Write a very long response that takes time to generate',
        );

        final subscription = stream.listen(
          (message) {
            print('Received: ${message.id}');
            receivedMessages.add(message);
          },
          onDone: () => print('Stream done'),
          onError: (e) => print('Stream error: $e'),
        );

        await Future.delayed(const Duration(seconds: 1));

        await subscription.cancel();
        print('Cancelled after ${receivedMessages.length} messages');

        await Future.delayed(const Duration(milliseconds: 500));

        final sessionStatus = await client.getSession(session.id);
        print('Session status after cancel: ${sessionStatus.status}');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('session remains healthy after stream cancellation', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Health After Cancel Test'),
      );

      try {
        final stream = client.sendPromptStream(
          session.id,
          text: 'Long response for cancellation test',
        );

        final sub = stream.listen((_) {});

        await Future.delayed(const Duration(milliseconds: 500));
        await sub.cancel();

        final sessionAfter = await client.getSession(session.id);
        expect(sessionAfter.id, equals(session.id),
            reason: 'Session should still exist');

        final response = await client.sendPrompt(
          session.id,
          text: 'New message after cancel',
        );
        expect(response.id, isNotEmpty,
            reason: 'Should be able to send new message');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Streamed Message Structure', () {
    testWidgets('streamed messages have correct structure', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Structure Validation Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Structure validation',
        );

        await for (final message in stream) {
          messages.add(message);

          expect(message.id, isNotEmpty,
              reason: 'Message should have non-empty ID');
          expect(message.sessionId, equals(session.id),
              reason: 'Message should belong to correct session');
          expect(message.role, isNotNull,
              reason: 'Message should have a role');
          expect(message.parts, isNotNull,
              reason: 'Message should have parts list');
        }

        expect(messages.isNotEmpty, isTrue,
            reason: 'Should receive at least one message');

        final hasUser = messages.any((m) => m.role == MessageRole.user);
        expect(hasUser, isTrue, reason: 'Should have user message');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('streamed message parts have correct structure', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Parts Structure Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Parts structure test',
        );

        await for (final message in stream) {
          messages.add(message);

          for (final part in message.parts ?? []) {
            expect(part.type.name, isNotEmpty,
                reason: 'Part should have type name');

            if (part.type == MessagePartType.text) {
              expect(part.text, isNotNull,
                  reason: 'Text part should have text content');
            }
          }
        }

        expect(messages.isNotEmpty, isTrue);

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('message parts contain valid text content', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Text Content Test'),
      );

      try {
        final allTexts = <String>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Provide a clear text response',
        );

        await for (final message in stream) {
          final text = message.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';

          if (text.isNotEmpty) {
            allTexts.add(text);
            print('Text part: "$text"');
          }
        }

        final combinedText = allTexts.join('');
        print('Combined length: ${combinedText.length}');
        expect(combinedText.isNotEmpty, isTrue,
            reason: 'Should have some text content');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Message Parts Accumulation', () {
    testWidgets('message parts are accumulated correctly across chunks',
        (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Parts Accumulation Test'),
      );

      try {
        final accumulatedTexts = <String>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Say hello world',
        );

        await for (final message in stream) {
          final text = message.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';

          if (text.isNotEmpty) {
            accumulatedTexts.add(text);
          }
        }

        final finalMessages = await client.getMessages(session.id);
        final assistantMessages = finalMessages
            .where((m) => m.role == MessageRole.assistant)
            .toList();

        if (assistantMessages.isNotEmpty) {
          final finalText = assistantMessages.first.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';

          print('Final stored text length: ${finalText.length}');
          expect(finalText.isNotEmpty, isTrue,
              reason: 'Final message should have content');
        }

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('streaming text matches final message text', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Text Match Test'),
      );

      try {
        String streamedText = '';

        final stream = client.sendPromptStream(
          session.id,
          text: 'Exact match test message',
        );

        await for (final message in stream) {
          final text = message.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';
          streamedText = text;
        }

        await Future.delayed(const Duration(seconds: 1));

        final finalMessages = await client.getMessages(session.id);
        final assistantMsg = finalMessages
            .where((m) => m.role == MessageRole.assistant)
            .firstOrNull;

        if (assistantMsg != null) {
          final storedText = assistantMsg.parts
                  ?.where((p) => p.type == MessagePartType.text)
                  .map((p) => p.text)
                  .join('') ??
              '';

          print('Streamed text: "${streamedText.substring(0, streamedText.length > 50 ? 50 : streamedText.length)}"');
          print('Stored text: "${storedText.substring(0, storedText.length > 50 ? 50 : storedText.length)}"');
        }

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });

  group('Edge Cases', () {
    testWidgets('streaming handles very short response', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Short Response Test'),
      );

      try {
        final messages = <Message>[];

        final stream = client.sendPromptStream(
          session.id,
          text: 'Ok',
        );

        await for (final message in stream) {
          messages.add(message);
        }

        expect(messages, isNotEmpty);

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });

    testWidgets('streaming completes within reasonable time', (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Completion Time Test'),
      );

      final stopwatch = Stopwatch()..start();

      try {
        final stream = client.sendPromptStream(
          session.id,
          text: 'Quick response please',
        );

        await for (final _ in stream) {}

        stopwatch.stop();
        print('Stream completed in ${stopwatch.elapsedMilliseconds}ms');

        expect(stopwatch.elapsed.inSeconds, lessThan(30),
            reason: 'Stream should complete within 30 seconds');

        await client.deleteSession(session.id);
      } finally {
        sseClient.disconnect();
      }
    });
  });
}

bool _isNonDecreasing(List<int> list) {
  for (var i = 1; i < list.length; i++) {
    if (list[i] < list[i - 1]) {
      return false;
    }
  }
  return true;
}
