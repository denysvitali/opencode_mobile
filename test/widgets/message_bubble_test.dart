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

    testWidgets('displays reasoning part', (tester) async {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.reasoning, text: 'Thinking...'),
          MessagePart(type: MessagePartType.text, text: 'Final answer.'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(message: message),
          ),
        ),
      );

      expect(find.text('Thinking...'), findsOneWidget);
      expect(find.text('Final answer.'), findsOneWidget);
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
