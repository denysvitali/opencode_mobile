import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/tool.dart';

void main() {
  group('ToolParameter', () {
    group('fromJson', () {
      test('parses type, description, required', () {
        final json = {
          'type': 'string',
          'description': 'A parameter description',
          'required': true,
        };
        final param = ToolParameter.fromJson(json);
        expect(param.type, 'string');
        expect(param.description, 'A parameter description');
        expect(param.required, true);
      });

      test('parses nested properties as raw map', () {
        final json = {
          'type': 'object',
          'properties': {
            'innerProp': {
              'type': 'string',
              'description': 'Inner property',
            },
          },
        };
        final param = ToolParameter.fromJson(json);
        expect(param.type, 'object');
        expect(param.properties, isNotNull);
        expect(param.properties!['innerProp'], isA<Map<String, dynamic>>());
        expect(param.properties!['innerProp']['type'], 'string');
      });

      test('parses enum values list', () {
        final json = {
          'type': 'string',
          'enum': ['option1', 'option2', 'option3'],
        };
        final param = ToolParameter.fromJson(json);
        expect(param.enumValues, isNotNull);
        expect(param.enumValues!.length, 3);
        expect(param.enumValues, ['option1', 'option2', 'option3']);
      });

      test('parses enum values as mixed types', () {
        final json = {
          'type': 'string',
          'enum': ['option1', 2, true, null],
        };
        final param = ToolParameter.fromJson(json);
        expect(param.enumValues, isNotNull);
        expect(param.enumValues!.length, 4);
        expect(param.enumValues, ['option1', '2', 'true', 'null']);
      });

      test('defaults required to false when missing', () {
        final json = {'type': 'string'};
        final param = ToolParameter.fromJson(json);
        expect(param.required, false);
      });

      test('defaults type to string when missing', () {
        final json = <String, dynamic>{};
        final param = ToolParameter.fromJson(json);
        expect(param.type, 'string');
      });

      test('handles null optional fields', () {
        final json = {
          'type': 'string',
          'description': null,
          'required': null,
          'properties': null,
          'enum': null,
        };
        final param = ToolParameter.fromJson(json);
        expect(param.description, isNull);
        expect(param.required, false);
        expect(param.properties, isNull);
        expect(param.enumValues, isNull);
      });
    });
  });

  group('ToolInputSchema', () {
    group('fromJson', () {
      test('parses type, properties, required', () {
        final json = {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Search query',
              'required': true,
            },
          },
          'required': ['query'],
        };
        final schema = ToolInputSchema.fromJson(json);
        expect(schema.type, 'object');
        expect(schema.properties, isNotNull);
        expect(schema.properties['query'], isA<ToolParameter>());
        expect(schema.properties['query']!.type, 'string');
        expect(schema.required, ['query']);
      });

      test('defaults type to object when missing', () {
        final json = <String, dynamic>{};
        final schema = ToolInputSchema.fromJson(json);
        expect(schema.type, 'object');
      });

      test('defaults properties to empty map when missing', () {
        final json = <String, dynamic>{};
        final schema = ToolInputSchema.fromJson(json);
        expect(schema.properties, isNotNull);
        expect(schema.properties.isEmpty, true);
      });

      test('defaults required to empty list when missing', () {
        final json = <String, dynamic>{};
        final schema = ToolInputSchema.fromJson(json);
        expect(schema.required, isEmpty);
      });

      test('handles multiple required fields', () {
        final json = {
          'type': 'object',
          'required': ['name', 'age', 'email'],
        };
        final schema = ToolInputSchema.fromJson(json);
        expect(schema.required, ['name', 'age', 'email']);
      });

      test('handles empty properties', () {
        final json = <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{},
        };
        final schema = ToolInputSchema.fromJson(json);
        expect(schema.properties.isEmpty, true);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final schema = ToolInputSchema(
          type: 'object',
          properties: {
            'query': ToolParameter(
              type: 'string',
              description: 'Search query',
              required: true,
            ),
          },
          required: ['query'],
        );
        final json = schema.toJson();
        expect(json['type'], 'object');
        expect(json['properties'], isNotNull);
        expect(json['properties']['query']['type'], 'string');
        expect(json['properties']['query']['description'], 'Search query');
        expect(json['required'], ['query']);
      });

      test('serializes nested properties as raw map', () {
        final schema = ToolInputSchema(
          type: 'object',
          properties: {
            'nested': ToolParameter(
              type: 'object',
              properties: {
                'inner': {'type': 'string', 'description': 'Inner param'},
              },
            ),
          },
        );
        final json = schema.toJson();
        expect(json['properties']['nested']['type'], 'object');
        expect(json['properties']['nested']['properties']['inner']['type'], 'string');
      });

      test('serializes enum values', () {
        final schema = ToolInputSchema(
          type: 'object',
          properties: {
            'status': ToolParameter(
              type: 'string',
              enumValues: ['active', 'inactive', 'pending'],
            ),
          },
        );
        final json = schema.toJson();
        expect(json['properties']['status']['enum'], ['active', 'inactive', 'pending']);
      });

      test('produces valid JSON', () {
        final schema = ToolInputSchema(
          type: 'object',
          properties: {
            'name': ToolParameter(type: 'string'),
          },
          required: ['name'],
        );
        final jsonString = jsonEncode(schema.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('Tool', () {
    group('fromJson', () {
      test('parses name, description, inputSchema', () {
        final json = {
          'name': 'test_tool',
          'description': 'A test tool',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Search query',
              },
            },
          },
        };
        final tool = Tool.fromJson(json);
        expect(tool.name, 'test_tool');
        expect(tool.description, 'A test tool');
        expect(tool.inputSchema, isNotNull);
        expect(tool.inputSchema!.type, 'object');
        expect(tool.inputSchema!.properties['query']!.type, 'string');
      });

      test('handles missing description', () {
        final json = {
          'name': 'test_tool',
          'inputSchema': {
            'type': 'object',
          },
        };
        final tool = Tool.fromJson(json);
        expect(tool.name, 'test_tool');
        expect(tool.description, isNull);
        expect(tool.inputSchema, isNotNull);
      });

      test('handles missing inputSchema', () {
        final json = {
          'name': 'test_tool',
          'description': 'A test tool',
        };
        final tool = Tool.fromJson(json);
        expect(tool.name, 'test_tool');
        expect(tool.description, 'A test tool');
        expect(tool.inputSchema, isNull);
      });

      test('defaults name to empty string when missing', () {
        final json = <String, dynamic>{};
        final tool = Tool.fromJson(json);
        expect(tool.name, '');
      });

      test('handles null description', () {
        final json = {
          'name': 'test_tool',
          'description': null,
        };
        final tool = Tool.fromJson(json);
        expect(tool.description, isNull);
      });

      test('handles nested inputSchema properties', () {
        final json = {
          'name': 'nested_tool',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'config': {
                'type': 'object',
                'properties': {
                  'enabled': {
                    'type': 'boolean',
                    'description': 'Enable feature',
                  },
                },
              },
            },
          },
        };
        final tool = Tool.fromJson(json);
        expect(tool.inputSchema!.properties['config']!.type, 'object');
        expect(tool.inputSchema!.properties['config']!.properties, isNotNull);
        expect(tool.inputSchema!.properties['config']!.properties!['enabled']['type'], 'boolean');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final tool = Tool(
          name: 'test_tool',
          description: 'A test tool',
          inputSchema: ToolInputSchema(
            type: 'object',
            properties: {
              'query': ToolParameter(type: 'string'),
            },
          ),
        );
        final json = tool.toJson();
        expect(json['name'], 'test_tool');
        expect(json['description'], 'A test tool');
        expect(json['inputSchema'], isNotNull);
        expect(json['inputSchema']['type'], 'object');
      });

      test('omits null description', () {
        final tool = Tool(
          name: 'test_tool',
          inputSchema: ToolInputSchema(),
        );
        final json = tool.toJson();
        expect(json.containsKey('description'), false);
        expect(json['name'], 'test_tool');
      });

      test('omits null inputSchema', () {
        final tool = Tool(
          name: 'test_tool',
          description: 'A test tool',
        );
        final json = tool.toJson();
        expect(json.containsKey('inputSchema'), false);
        expect(json['description'], 'A test tool');
      });

      test('produces valid JSON', () {
        final tool = Tool(
          name: 'test_tool',
          description: 'A test tool',
          inputSchema: ToolInputSchema(
            type: 'object',
            properties: {
              'query': ToolParameter(type: 'string'),
            },
          ),
        );
        final jsonString = jsonEncode(tool.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('ToolList', () {
    group('fromJson', () {
      test('parses tools array', () {
        final json = {
          'tools': [
            {
              'name': 'tool_one',
              'description': 'First tool',
            },
            {
              'name': 'tool_two',
              'description': 'Second tool',
              'inputSchema': {
                'type': 'object',
              },
            },
          ],
        };
        final toolList = ToolList.fromJson(json);
        expect(toolList.tools.length, 2);
        expect(toolList.tools[0].name, 'tool_one');
        expect(toolList.tools[0].description, 'First tool');
        expect(toolList.tools[1].name, 'tool_two');
        expect(toolList.tools[1].inputSchema, isNotNull);
      });

      test('handles empty tools array', () {
        final json = {'tools': <dynamic>[]};
        final toolList = ToolList.fromJson(json);
        expect(toolList.tools, isEmpty);
      });

      test('handles missing tools key', () {
        final json = <String, dynamic>{};
        final toolList = ToolList.fromJson(json);
        expect(toolList.tools, isEmpty);
      });

      test('handles null tools array', () {
        final json = {'tools': null};
        final toolList = ToolList.fromJson(json);
        expect(toolList.tools, isEmpty);
      });
    });
  });
}
