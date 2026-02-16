import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/message.dart';

void main() {
  group('Message', () {
    test('creates with default values', () {
      final message = Message(
        sessionId: 'session-1',
        role: MessageRole.user,
      );
      expect(message.id, isNotEmpty);
      expect(message.sessionId, 'session-1');
      expect(message.role, MessageRole.user);
      expect(message.createdAt, isNotNull);
      expect(message.parts, isEmpty);
    });

    group('fromJson', () {
      test('parses basic message with id, sessionID, role', () {
        final json = {
          'id': 'msg-1',
          'sessionID': 'session-1',
          'role': 'assistant',
        };
        final message = Message.fromJson(json);
        expect(message.id, 'msg-1');
        expect(message.sessionId, 'session-1');
        expect(message.role, MessageRole.assistant);
      });

      test('handles user role', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'user',
        };
        final message = Message.fromJson(json);
        expect(message.role, MessageRole.user);
      });

      test('handles parts array with text type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'text', 'text': 'Hello world'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts.length, 1);
        expect(message.parts[0].type, MessagePartType.text);
        expect(message.parts[0].text, 'Hello world');
      });

      test('handles parts array with reasoning type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'reasoning', 'text': 'Let me think...'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.reasoning);
        expect(message.parts[0].text, 'Let me think...');
      });

      test('handles parts array with tool type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {
              'type': 'tool',
              'tool': {
                'name': 'Bash',
                'state': 'completed',
                'input': 'ls -la',
                'output': 'total 10',
              },
            },
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.tool);
        expect(message.parts[0].toolName, 'Bash');
        expect(message.parts[0].toolState, 'completed');
        expect(message.parts[0].toolInput, 'ls -la');
        expect(message.parts[0].toolOutput, 'total 10');
      });

      test('handles tool-call type as tool', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {
              'type': 'tool-call',
              'tool': {'name': 'Read', 'state': 'running'},
            },
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.tool);
      });

      test('handles parts array with file type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {
              'type': 'file',
              'file': {'path': '/test/file.txt', 'content': 'file content'},
            },
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.file);
        expect(message.parts[0].fileData, isNotNull);
        expect(message.parts[0].fileData!['path'], '/test/file.txt');
      });

      test('handles step-start type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'step-start', 'text': 'Starting step 1'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.stepStart);
      });

      test('handles step-finish type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'step-finish', 'text': 'Finished step 1'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.stepFinish);
      });

      test('handles snapshot type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'snapshot', 'text': '{"key": "value"}'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.snapshot);
      });

      test('handles patch type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'patch', 'text': '--- a/file\n+++ b/file'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.patch);
      });

      test('handles error type', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parts': [
            {'type': 'error', 'error': 'Something went wrong'},
          ],
        };
        final message = Message.fromJson(json);
        expect(message.parts[0].type, MessagePartType.error);
        expect(message.parts[0].error, 'Something went wrong');
      });

      test('handles time.created', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'time': {'created': 1700000000000},
        };
        final message = Message.fromJson(json);
        expect(message.createdAt.millisecondsSinceEpoch, 1700000000000);
      });

      test('handles time.completed', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'time': {'created': 1700000000000, 'completed': 1700000001000},
        };
        final message = Message.fromJson(json);
        expect(message.completedAt!.millisecondsSinceEpoch, 1700000001000);
      });

      test('handles modelID', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'modelID': 'gpt-4',
        };
        final message = Message.fromJson(json);
        expect(message.modelId, 'gpt-4');
      });

      test('handles providerID', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'providerID': 'openai',
        };
        final message = Message.fromJson(json);
        expect(message.providerId, 'openai');
      });

      test('handles cost', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'cost': 0.005,
        };
        final message = Message.fromJson(json);
        expect(message.cost, 0.005);
      });

      test('handles cost as int', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'cost': 5,
        };
        final message = Message.fromJson(json);
        expect(message.cost, 5.0);
      });

      test('handles tokens', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'tokens': {'input': 100, 'output': 50},
        };
        final message = Message.fromJson(json);
        expect(message.tokens, isNotNull);
        expect(message.tokens!['input'], 100);
        expect(message.tokens!['output'], 50);
      });

      test('handles error messages', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'error': {'message': 'API Error occurred'},
        };
        final message = Message.fromJson(json);
        expect(message.error, 'API Error occurred');
      });

      test('handles parentID', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'parentID': 'parent-msg-1',
        };
        final message = Message.fromJson(json);
        expect(message.parentMessageId, 'parent-msg-1');
      });

      test('handles sessionId variant', () {
        final json = {
          'sessionId': 'session-variant',
          'role': 'user',
        };
        final message = Message.fromJson(json);
        expect(message.sessionId, 'session-variant');
      });

      test('handles missing optional fields', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'user',
        };
        final message = Message.fromJson(json);
        expect(message.id, isNotEmpty);
        expect(message.completedAt, isNull);
        expect(message.parts, isEmpty);
        expect(message.parentMessageId, isNull);
        expect(message.modelId, isNull);
        expect(message.providerId, isNull);
        expect(message.cost, isNull);
        expect(message.tokens, isNull);
        expect(message.error, isNull);
      });

      test('handles finish reason', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'assistant',
          'finish': 'stop',
        };
        final message = Message.fromJson(json);
        expect(message.finishReason, 'stop');
      });

      test('handles empty parts list', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'user',
          'parts': <dynamic>[],
        };
        final message = Message.fromJson(json);
        expect(message.parts, isEmpty);
      });

      test('handles null parts', () {
        final json = {
          'sessionID': 'session-1',
          'role': 'user',
          'parts': null,
        };
        final message = Message.fromJson(json);
        expect(message.parts, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all basic fields correctly', () {
        final message = Message(
          id: 'msg-1',
          sessionId: 'session-1',
          role: MessageRole.assistant,
        );
        final json = message.toJson();
        expect(json['id'], 'msg-1');
        expect(json['sessionID'], 'session-1');
        expect(json['role'], 'assistant');
        expect(json['time']['created'], message.createdAt.millisecondsSinceEpoch);
      });

      test('includes completedAt when present', () {
        final completedAt = DateTime.fromMillisecondsSinceEpoch(1700000001000);
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          completedAt: completedAt,
        );
        final json = message.toJson();
        expect(json['time']['completed'], completedAt.millisecondsSinceEpoch);
      });

      test('handles parts with different types', () {
        final parts = [
          MessagePart(type: MessagePartType.text, text: 'Hello'),
          MessagePart(
            type: MessagePartType.tool,
            toolData: {'name': 'Bash', 'state': 'completed'},
          ),
        ];
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: parts,
        );
        final json = message.toJson();
        expect(json['parts'], isA<List>());
        expect((json['parts'] as List).length, 2);
      });

      test('serializes text parts correctly', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [MessagePart(type: MessagePartType.text, text: 'Test')],
        );
        final json = message.toJson();
        final partsJson = json['parts'] as List;
        expect(partsJson[0]['type'], 'text');
        expect(partsJson[0]['text'], 'Test');
      });

      test('serializes tool parts correctly', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(
              type: MessagePartType.tool,
              toolData: {'name': 'Read', 'state': 'running'},
            ),
          ],
        );
        final json = message.toJson();
        final partsJson = json['parts'] as List;
        expect(partsJson[0]['type'], 'tool');
        expect(partsJson[0]['tool'], isNotNull);
        expect(partsJson[0]['tool']['name'], 'Read');
      });

      test('omits null text in parts', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [MessagePart(type: MessagePartType.tool, toolData: {})],
        );
        final json = message.toJson();
        final partsJson = json['parts'] as List;
        expect(partsJson[0].containsKey('text'), false);
      });

      test('includes part id in serialization', () {
        final part = MessagePart(type: MessagePartType.text, text: 'Test');
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [part],
        );
        final json = message.toJson();
        final partsJson = json['parts'] as List;
        expect(partsJson[0]['id'], part.id);
      });
    });

    group('copyWith', () {
      test('updates specific fields', () {
        final original = Message(
          id: 'msg-1',
          sessionId: 'session-1',
          role: MessageRole.user,
        );
        final updated = original.copyWith(
          role: MessageRole.assistant,
          modelId: 'gpt-4',
        );
        expect(updated.id, 'msg-1');
        expect(updated.sessionId, 'session-1');
        expect(updated.role, MessageRole.assistant);
        expect(updated.modelId, 'gpt-4');
      });

      test('preserves unchanged fields', () {
        final createdAt = DateTime.now();
        final completedAt = DateTime.now().add(Duration(minutes: 5));
        final original = Message(
          id: 'msg-1',
          sessionId: 'session-1',
          role: MessageRole.assistant,
          createdAt: createdAt,
          completedAt: completedAt,
          parts: [MessagePart(type: MessagePartType.text, text: 'Hello')],
        );
        final updated = original.copyWith(error: 'New error');
        expect(updated.id, original.id);
        expect(updated.sessionId, original.sessionId);
        expect(updated.role, original.role);
        expect(updated.createdAt, original.createdAt);
        expect(updated.completedAt, original.completedAt);
        expect(updated.parts, original.parts);
        expect(updated.error, 'New error');
      });

      test('can update multiple fields', () {
        final original = Message(
          sessionId: 'session-1',
          role: MessageRole.user,
        );
        final updated = original.copyWith(
          sessionId: 'session-2',
          role: MessageRole.assistant,
          modelId: 'gpt-4',
          providerId: 'openai',
          cost: 0.01,
        );
        expect(updated.sessionId, 'session-2');
        expect(updated.role, MessageRole.assistant);
        expect(updated.modelId, 'gpt-4');
        expect(updated.providerId, 'openai');
        expect(updated.cost, 0.01);
      });

      test('can update parts list', () {
        final original = Message(
          sessionId: 'session-1',
          role: MessageRole.user,
          parts: [MessagePart(type: MessagePartType.text, text: 'Original')],
        );
        final updated = original.copyWith(
          parts: [MessagePart(type: MessagePartType.text, text: 'Updated')],
        );
        expect(original.parts.length, 1);
        expect(original.parts[0].text, 'Original');
        expect(updated.parts.length, 1);
        expect(updated.parts[0].text, 'Updated');
      });
    });

    group('textContent', () {
      test('concatenates all text parts', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.text, text: 'Hello'),
            MessagePart(type: MessagePartType.text, text: 'World'),
          ],
        );
        expect(message.textContent, 'Hello\nWorld');
      });

      test('returns empty string with no text parts', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
        );
        expect(message.textContent, '');
      });

      test('ignores null text in concatenation', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.text, text: 'Hello'),
            MessagePart(type: MessagePartType.text, text: 'World'),
          ],
        );
        expect(message.textContent, 'Hello\nWorld');
      });

      test('ignores non-text parts', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.text, text: 'Hello'),
            MessagePart(type: MessagePartType.tool, toolData: {'name': 'Bash'}),
            MessagePart(type: MessagePartType.reasoning, text: 'Thinking'),
          ],
        );
        expect(message.textContent, 'Hello');
      });

      test('returns empty string when all parts are non-text', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.tool, toolData: {'name': 'Bash'}),
            MessagePart(type: MessagePartType.file, fileData: {'path': '/test'}),
          ],
        );
        expect(message.textContent, '');
      });
    });

    group('toolParts', () {
      test('filters tool parts', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.text, text: 'Hello'),
            MessagePart(
              type: MessagePartType.tool,
              toolData: {'name': 'Bash', 'state': 'completed'},
            ),
            MessagePart(type: MessagePartType.reasoning, text: 'Thinking'),
            MessagePart(
              type: MessagePartType.tool,
              toolData: {'name': 'Read', 'state': 'running'},
            ),
          ],
        );
        expect(message.toolParts.length, 2);
        expect(message.toolParts[0].toolName, 'Bash');
        expect(message.toolParts[1].toolName, 'Read');
      });

      test('returns empty list when no tool parts', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
          parts: [
            MessagePart(type: MessagePartType.text, text: 'Hello'),
          ],
        );
        expect(message.toolParts, isEmpty);
      });

      test('returns empty list for empty message', () {
        final message = Message(
          sessionId: 'session-1',
          role: MessageRole.assistant,
        );
        expect(message.toolParts, isEmpty);
      });
    });
  });

  group('MessagePart', () {
    test('creates with default id', () {
      final part = MessagePart(type: MessagePartType.text);
      expect(part.id, isNotEmpty);
    });

    test('creates with custom id', () {
      final part = MessagePart(
        id: 'custom-id',
        type: MessagePartType.text,
      );
      expect(part.id, 'custom-id');
    });

    group('fromJson', () {
      test('parses text parts', () {
        final json = {'type': 'text', 'text': 'Hello world'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.text);
        expect(part.text, 'Hello world');
      });

      test('parses reasoning parts', () {
        final json = {'type': 'reasoning', 'text': 'Let me think'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.reasoning);
        expect(part.text, 'Let me think');
      });

      test('parses tool parts with name, state, input, output', () {
        final json = {
          'type': 'tool',
          'tool': {
            'name': 'Bash',
            'state': 'running',
            'input': 'ls',
            'output': 'file1 file2',
          },
        };
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.tool);
        expect(part.toolName, 'Bash');
        expect(part.toolState, 'running');
        expect(part.toolInput, 'ls');
        expect(part.toolOutput, 'file1 file2');
      });

      test('parses file parts', () {
        final json = {
          'type': 'file',
          'file': {'path': '/test.txt', 'content': 'content'},
        };
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.file);
        expect(part.fileData, isNotNull);
        expect(part.fileData!['path'], '/test.txt');
      });

      test('handles unknown type defaults to text', () {
        final json = {'type': 'unknown'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.text);
      });

      test('handles null type defaults to text', () {
        final json = <String, dynamic>{};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.text);
      });

      test('parses step-start type', () {
        final json = {'type': 'step-start', 'text': 'Starting'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.stepStart);
      });

      test('parses step-finish type', () {
        final json = {'type': 'step-finish', 'text': 'Finished'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.stepFinish);
      });

      test('parses snapshot type', () {
        final json = {'type': 'snapshot', 'text': '{"key": "value"}'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.snapshot);
      });

      test('parses patch type', () {
        final json = {'type': 'patch', 'text': 'diff content'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.patch);
      });

      test('parses error type', () {
        final json = {'type': 'error', 'error': 'Error message'};
        final part = MessagePart.fromJson(json);
        expect(part.type, MessagePartType.error);
        expect(part.error, 'Error message');
      });

      test('parses custom id', () {
        final json = {'id': 'part-1', 'type': 'text', 'text': 'Hello'};
        final part = MessagePart.fromJson(json);
        expect(part.id, 'part-1');
      });
    });

    group('toolName', () {
      test('returns tool name from toolData', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'name': 'Bash'},
        );
        expect(part.toolName, 'Bash');
      });

      test('returns null when toolData is null', () {
        final part = MessagePart(type: MessagePartType.tool);
        expect(part.toolName, isNull);
      });

      test('returns null when name not in toolData', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'completed'},
        );
        expect(part.toolName, isNull);
      });
    });

    group('toolState', () {
      test('returns tool state from toolData', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'running'},
        );
        expect(part.toolState, 'running');
      });

      test('returns null when toolData is null', () {
        final part = MessagePart(type: MessagePartType.tool);
        expect(part.toolState, isNull);
      });
    });

    group('toolInput', () {
      test('returns tool input as string', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'input': 'ls -la'},
        );
        expect(part.toolInput, 'ls -la');
      });

      test('handles non-string input', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'input': 123},
        );
        expect(part.toolInput, '123');
      });

      test('returns null when input not present', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'name': 'test'},
        );
        expect(part.toolInput, isNull);
      });
    });

    group('toolOutput', () {
      test('returns tool output as string', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'output': 'result'},
        );
        expect(part.toolOutput, 'result');
      });

      test('handles non-string output', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'output': 42},
        );
        expect(part.toolOutput, '42');
      });

      test('returns null when output not present', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'name': 'test'},
        );
        expect(part.toolOutput, isNull);
      });
    });

    group('isToolPending', () {
      test('returns true when state is pending', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'pending'},
        );
        expect(part.isToolPending, true);
      });

      test('returns false when state is not pending', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'completed'},
        );
        expect(part.isToolPending, false);
      });

      test('returns false when toolData is null', () {
        final part = MessagePart(type: MessagePartType.tool);
        expect(part.isToolPending, false);
      });

      test('returns false when state is missing', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'name': 'test'},
        );
        expect(part.isToolPending, false);
      });
    });

    group('isToolRunning', () {
      test('returns true when state is running', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'running'},
        );
        expect(part.isToolRunning, true);
      });

      test('returns false when state is not running', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'pending'},
        );
        expect(part.isToolRunning, false);
      });

      test('returns false when toolData is null', () {
        final part = MessagePart(type: MessagePartType.tool);
        expect(part.isToolRunning, false);
      });
    });

    group('isToolCompleted', () {
      test('returns true when state is completed', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'completed'},
        );
        expect(part.isToolCompleted, true);
      });

      test('returns false when state is not completed', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'running'},
        );
        expect(part.isToolCompleted, false);
      });

      test('returns false when toolData is null', () {
        final part = MessagePart(type: MessagePartType.tool);
        expect(part.isToolCompleted, false);
      });
    });

    group('isToolError', () {
      test('returns true when state is error', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'error'},
        );
        expect(part.isToolError, true);
      });

      test('returns false when state is not error', () {
        final part = MessagePart(
          type: MessagePartType.tool,
          toolData: {'state': 'completed'},
        );
        expect(part.isToolError, false);
      });

      test('returns false when toolData is null', () {
        final part = MessagePart(type: MessagePartType.tool);
        expect(part.isToolError, false);
      });
    });
  });

  group('MessageRole', () {
    test('has user value', () {
      expect(MessageRole.user.name, 'user');
    });

    test('has assistant value', () {
      expect(MessageRole.assistant.name, 'assistant');
    });
  });

  group('MessagePartType', () {
    test('has all expected values', () {
      expect(MessagePartType.values, contains(MessagePartType.text));
      expect(MessagePartType.values, contains(MessagePartType.reasoning));
      expect(MessagePartType.values, contains(MessagePartType.tool));
      expect(MessagePartType.values, contains(MessagePartType.file));
      expect(MessagePartType.values, contains(MessagePartType.stepStart));
      expect(MessagePartType.values, contains(MessagePartType.stepFinish));
      expect(MessagePartType.values, contains(MessagePartType.snapshot));
      expect(MessagePartType.values, contains(MessagePartType.patch));
      expect(MessagePartType.values, contains(MessagePartType.error));
    });
  });
}
