import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/message.dart';

void main() {
  group('Message', () {
    test('creates with required values', () {
      final message = Message(
        sessionId: 'session-1',
        role: MessageRole.user,
      );
      expect(message.id, isNotEmpty);
      expect(message.sessionId, 'session-1');
      expect(message.role, MessageRole.user);
      expect(message.parts, isEmpty);
    });

    test('fromJson parses basic message', () {
      final json = {
        'id': 'msg-1',
        'sessionID': 'session-1',
        'role': 'assistant',
        'parts': [
          {'type': 'text', 'text': 'Hello'},
        ],
      };
      final message = Message.fromJson(json);
      expect(message.id, 'msg-1');
      expect(message.sessionId, 'session-1');
      expect(message.role, MessageRole.assistant);
      expect(message.parts.length, 1);
      expect(message.parts[0].type, MessagePartType.text);
      expect(message.parts[0].text, 'Hello');
    });

    test('fromJson parses different role variants', () {
      expect(Message.fromJson({'sessionID': 's', 'role': 'user'}).role, MessageRole.user);
      expect(Message.fromJson({'sessionID': 's', 'role': 'assistant'}).role, MessageRole.assistant);
      expect(Message.fromJson({'sessionID': 's', 'role': 'unknown'}).role, MessageRole.user);
    });

    test('fromJson parses message with tool part', () {
      final json = {
        'id': 'msg-1',
        'sessionID': 'session-1',
        'role': 'assistant',
        'parts': [
          {
            'type': 'tool-call',
            'tool': {'name': 'bash', 'state': 'running', 'input': 'ls'},
          },
        ],
      };
      final message = Message.fromJson(json);
      expect(message.parts.length, 1);
      expect(message.parts[0].type, MessagePartType.tool);
      expect(message.parts[0].toolName, 'bash');
      expect(message.parts[0].toolState, 'running');
      expect(message.parts[0].toolInput, 'ls');
    });

    test('textContent returns combined text parts', () {
      final message = Message(
        sessionId: 's',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.text, text: 'Hello '),
          MessagePart(type: MessagePartType.text, text: 'World'),
        ],
      );
      expect(message.textContent, 'Hello \nWorld');
    });

    test('textContent ignores non-text parts', () {
      final message = Message(
        sessionId: 's',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.text, text: 'Hello'),
          MessagePart(type: MessagePartType.tool, toolData: {'name': 'test'}),
        ],
      );
      expect(message.textContent, 'Hello');
    });

    test('toolParts returns only tool parts', () {
      final message = Message(
        sessionId: 's',
        role: MessageRole.assistant,
        parts: [
          MessagePart(type: MessagePartType.text, text: 'Hello'),
          MessagePart(type: MessagePartType.tool, toolData: {'name': 'bash'}),
          MessagePart(type: MessagePartType.tool, toolData: {'name': 'read'}),
        ],
      );
      expect(message.toolParts.length, 2);
    });

    test('copyWith creates new instance', () {
      final message = Message(
        id: 'original',
        sessionId: 'session-1',
        role: MessageRole.user,
      );
      final updated = message.copyWith(
        role: MessageRole.assistant,
        finishReason: 'stop',
      );
      expect(updated.id, 'original');
      expect(updated.role, MessageRole.assistant);
      expect(updated.finishReason, 'stop');
    });

    test('toJson produces correct output', () {
      final message = Message(
        id: 'msg-1',
        sessionId: 'session-1',
        role: MessageRole.assistant,
        parts: [MessagePart(type: MessagePartType.text, text: 'Test')],
      );
      final json = message.toJson();
      expect(json['id'], 'msg-1');
      expect(json['sessionID'], 'session-1');
      expect(json['role'], 'assistant');
      expect((json['parts'] as List).length, 1);
    });
  });

  group('MessagePart', () {
    test('creates with type', () {
      final part = MessagePart(type: MessagePartType.text, text: 'Hello');
      expect(part.id, isNotEmpty);
      expect(part.type, MessagePartType.text);
      expect(part.text, 'Hello');
    });

    test('fromJson parses all part types', () {
      expect(MessagePart.fromJson({'type': 'text'}).type, MessagePartType.text);
      expect(MessagePart.fromJson({'type': 'reasoning'}).type, MessagePartType.reasoning);
      expect(MessagePart.fromJson({'type': 'tool-call'}).type, MessagePartType.tool);
      expect(MessagePart.fromJson({'type': 'file'}).type, MessagePartType.file);
      expect(MessagePart.fromJson({'type': 'step-start'}).type, MessagePartType.stepStart);
      expect(MessagePart.fromJson({'type': 'step-finish'}).type, MessagePartType.stepFinish);
      expect(MessagePart.fromJson({'type': 'snapshot'}).type, MessagePartType.snapshot);
      expect(MessagePart.fromJson({'type': 'patch'}).type, MessagePartType.patch);
      expect(MessagePart.fromJson({'type': 'error'}).type, MessagePartType.error);
      expect(MessagePart.fromJson({'type': 'unknown'}).type, MessagePartType.text);
    });

    test('tool state checks work correctly', () {
      final pending = MessagePart(
        type: MessagePartType.tool,
        toolData: {'state': 'pending'},
      );
      final running = MessagePart(
        type: MessagePartType.tool,
        toolData: {'state': 'running'},
      );
      final completed = MessagePart(
        type: MessagePartType.tool,
        toolData: {'state': 'completed'},
      );
      final error = MessagePart(
        type: MessagePartType.tool,
        toolData: {'state': 'error'},
      );

      expect(pending.isToolPending, true);
      expect(pending.isToolRunning, false);
      expect(running.isToolRunning, true);
      expect(completed.isToolCompleted, true);
      expect(error.isToolError, true);
    });

    test('toolName returns correct value', () {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'name': 'bash'},
      );
      expect(part.toolName, 'bash');
    });

    test('toolInput returns correct value', () {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'input': 'ls -la'},
      );
      expect(part.toolInput, 'ls -la');
    });

    test('toolOutput returns correct value', () {
      final part = MessagePart(
        type: MessagePartType.tool,
        toolData: {'output': 'file.txt'},
      );
      expect(part.toolOutput, 'file.txt');
    });
  });
}
