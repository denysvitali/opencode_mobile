import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/features/chat/widgets/message_bubble.dart';

void main() {
  group('MessageBubble Widget Tests', () {
    testWidgets('displays user message correctly', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.user,
        parts: [MessagePart(type: MessagePartType.text, text: 'Hello, world!')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Hello, world!'), findsOneWidget);
    });

    testWidgets('displays assistant message correctly', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        parts: [MessagePart(type: MessagePartType.text, text: 'I am an assistant.')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('I am an assistant.'), findsOneWidget);
    });

    testWidgets('displays multiple text parts', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.text, text: 'First part. '),
          MessagePart(type: MessagePartType.text, text: 'Second part.'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.textContaining('First part'), findsOneWidget);
      expect(find.textContaining('Second part'), findsOneWidget);
    });

    testWidgets('displays reasoning part with expand/collapse', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.reasoning, text: 'Let me analyze this step by step.'),
          MessagePart(type: MessagePartType.text, text: 'Final answer.'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(message: message),
            ),
          ),
        ),
      );

      // Header should be visible
      expect(find.text('Thinking...'), findsOneWidget);
      // Content should be hidden (collapsed by default)
      expect(find.text('Let me analyze this step by step.'), findsNothing);
      // Text part should be visible
      expect(find.text('Final answer.'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Thinking...'));
      await tester.pumpAndSettle();

      // Content should now be visible
      expect(find.text('Let me analyze this step by step.'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.text('Thinking...'));
      await tester.pumpAndSettle();

      // Content should be hidden again
      expect(find.text('Let me analyze this step by step.'), findsNothing);
    });

    testWidgets('displays error message', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        error: 'Something went wrong',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('displays error part', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.error, error: 'Tool failed'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Tool failed'), findsOneWidget);
    });
  });
}
