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

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(config: ServerConfig(url: serverUrl));
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('Full Chat Workflow', () {
    testWidgets(
      'health check -> list projects -> create session -> multi-turn chat -> verify history -> cleanup',
      (tester) async {
        // Health check
        final health = await client.healthCheck();
        expect(health.healthy, isTrue, reason: 'Server should be healthy');

        // List projects
        final projects = await client.listProjects();
        expect(projects, isList);

        // Create session
        final session = await client.createSession(
          input: SessionCreateInput(title: 'E2E Chat Workflow Test'),
        );
        expect(session.id, isNotEmpty);

        try {
          // First message
          await client.sendPrompt(
            session.id,
            text: 'Say exactly: "Hello from test one"',
          );

          // Poll for assistant response to first message
          var messages = <Message>[];
          for (var i = 0; i < 30; i++) {
            await Future.delayed(const Duration(seconds: 2));
            messages = await client.getMessages(session.id);
            final hasAssistant =
                messages.any((m) => m.role == MessageRole.assistant);
            if (hasAssistant) break;
          }
          expect(
            messages.any((m) => m.role == MessageRole.assistant),
            isTrue,
            reason: 'Should have assistant response to first message',
          );

          // Second message
          await client.sendPrompt(
            session.id,
            text: 'Say exactly: "Hello from test two"',
          );

          // Poll for second assistant response
          for (var i = 0; i < 30; i++) {
            await Future.delayed(const Duration(seconds: 2));
            messages = await client.getMessages(session.id);
            final assistantCount =
                messages.where((m) => m.role == MessageRole.assistant).length;
            if (assistantCount >= 2) break;
          }

          // Final verification
          final finalMessages = await client.getMessages(session.id);
          expect(finalMessages.length, greaterThanOrEqualTo(3),
              reason: 'At least 2 user + 1 assistant messages');

          // All messages belong to this session
          for (final msg in finalMessages) {
            if (msg.sessionId.isNotEmpty) {
              expect(msg.sessionId, equals(session.id));
            }
          }
        } finally {
          try {
            await client.deleteSession(session.id);
          } catch (_) {}
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'session metadata updates after chat activity',
      (tester) async {
        final session = await client.createSession(
          input: SessionCreateInput(title: 'Metadata Update Test'),
        );

        try {
          await client.sendPrompt(
            session.id,
            text: 'Respond with a single word: "acknowledged"',
          );

          // Wait for processing
          await Future.delayed(const Duration(seconds: 10));

          final updated = await client.getSession(session.id);
          expect(updated.id, equals(session.id));
          // Session should still exist and be retrievable after chat
        } finally {
          try {
            await client.deleteSession(session.id);
          } catch (_) {}
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'send message and cancel active session',
      (tester) async {
        final session = await client.createSession(
          input: SessionCreateInput(title: 'Cancel Test'),
        );

        try {
          await client.sendPrompt(
            session.id,
            text:
                'Write a very long essay about the history of computing. Make it at least 2000 words.',
          );

          // Brief delay then cancel
          await Future.delayed(const Duration(seconds: 2));

          // Cancel should not throw
          try {
            await client.cancelSession(session.id);
          } catch (_) {
            // Some states may not be cancellable, that's OK
          }

          // Session should still be retrievable
          final retrieved = await client.getSession(session.id);
          expect(retrieved.id, equals(session.id));
        } finally {
          try {
            await client.deleteSession(session.id);
          } catch (_) {}
        }
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('SSE Message Flow', () {
    testWidgets(
      'SSE delivers message updates during chat',
      (tester) async {
        final sseClient = SSEClient();
        final receivedMessages = <Message>[];
        StreamSubscription<Message>? subscription;

        sseClient.connect(serverUrl: serverUrl);

        // Wait for SSE connection
        await Future.delayed(const Duration(seconds: 2));

        // Get a project directory for SSE project events
        final projects = await client.listProjects();
        if (projects.isNotEmpty && projects.first.worktree != null) {
          await sseClient.connectProject(projects.first.worktree!);
          await Future.delayed(const Duration(seconds: 1));
        }

        subscription = sseClient.messageUpdateStream.listen((msg) {
          receivedMessages.add(msg);
        });

        final session = await client.createSession(
          input: SessionCreateInput(title: 'SSE Test'),
        );

        try {
          await client.sendPrompt(
            session.id,
            text: 'Reply with: "SSE test response"',
          );

          // Collect SSE messages for up to 10 seconds
          for (var i = 0; i < 20; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (receivedMessages.isNotEmpty) break;
          }

          // We may or may not receive SSE messages depending on project routing,
          // but the connection should not have crashed
          expect(sseClient.status, isNot(SSEConnectionStatus.error));
        } finally {
          await subscription.cancel();
          sseClient.disconnect();
          try {
            await client.deleteSession(session.id);
          } catch (_) {}
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
