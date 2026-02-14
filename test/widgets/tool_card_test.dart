import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/features/chat/widgets/tool_card.dart';

void main() {
  group('ToolCard Widget Tests', () {
    testWidgets('displays tool name', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'pending', 'input': 'ls'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('bash'), findsOneWidget);
    });

    testWidgets('displays pending state indicator', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'pending', 'input': 'ls'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('displays running state indicator', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'running', 'input': 'ls'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Running...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays completed state indicator', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'completed', 'input': 'ls', 'output': 'file.txt'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('displays error state indicator', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'error', 'input': 'ls', 'output': 'Command failed'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('displays tool icon for bash', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'pending'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.terminal), findsOneWidget);
    });

    testWidgets('displays tool icon for read', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'read', 'state': 'pending'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('handles unknown tool gracefully', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'state': 'pending'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('shows input section when input exists', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'completed', 'input': 'ls -la'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Input'), findsOneWidget);
    });

    testWidgets('shows output section when output exists', (tester) async {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash', 'state': 'completed', 'input': 'ls', 'output': 'file.txt'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolCard(part: part),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Output'), findsOneWidget);
    });
  });
}
