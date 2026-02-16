import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/mcp_resource.dart';

void main() {
  group('McpResource', () {
    group('fromJson', () {
      test('parses uri, name, description, mimeType', () {
        final json = {
          'uri': 'file:///test/path.txt',
          'name': 'Test File',
          'description': 'A test file resource',
          'mimeType': 'text/plain',
        };
        final resource = McpResource.fromJson(json);
        expect(resource.uri, 'file:///test/path.txt');
        expect(resource.name, 'Test File');
        expect(resource.description, 'A test file resource');
        expect(resource.mimeType, 'text/plain');
      });

      test('handles missing optional fields', () {
        final json = {
          'uri': 'file:///test/path.txt',
          'name': 'Test File',
        };
        final resource = McpResource.fromJson(json);
        expect(resource.uri, 'file:///test/path.txt');
        expect(resource.name, 'Test File');
        expect(resource.description, isNull);
        expect(resource.mimeType, isNull);
      });

      test('handles null optional fields', () {
        final json = {
          'uri': 'file:///test/path.txt',
          'name': 'Test File',
          'description': null,
          'mimeType': null,
        };
        final resource = McpResource.fromJson(json);
        expect(resource.description, isNull);
        expect(resource.mimeType, isNull);
      });

      test('defaults to empty string for missing uri', () {
        final json = {'name': 'Test File'};
        final resource = McpResource.fromJson(json);
        expect(resource.uri, '');
      });

      test('defaults to empty string for missing name', () {
        final json = {'uri': 'file:///test/path.txt'};
        final resource = McpResource.fromJson(json);
        expect(resource.name, '');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final resource = McpResource(
          uri: 'file:///test/path.txt',
          name: 'Test File',
          description: 'A test file resource',
          mimeType: 'text/plain',
        );
        final json = resource.toJson();
        expect(json['uri'], 'file:///test/path.txt');
        expect(json['name'], 'Test File');
        expect(json['description'], 'A test file resource');
        expect(json['mimeType'], 'text/plain');
      });

      test('omits null description', () {
        final resource = McpResource(
          uri: 'file:///test/path.txt',
          name: 'Test File',
        );
        final json = resource.toJson();
        expect(json.containsKey('description'), false);
        expect(json['uri'], 'file:///test/path.txt');
        expect(json['name'], 'Test File');
      });

      test('omits null mimeType', () {
        final resource = McpResource(
          uri: 'file:///test/path.txt',
          name: 'Test File',
          description: 'A test file resource',
        );
        final json = resource.toJson();
        expect(json.containsKey('mimeType'), false);
        expect(json['description'], 'A test file resource');
      });

      test('omits both null optional fields', () {
        final resource = McpResource(
          uri: 'file:///test/path.txt',
          name: 'Test File',
        );
        final json = resource.toJson();
        expect(json.containsKey('description'), false);
        expect(json.containsKey('mimeType'), false);
        expect(json.length, 2);
      });

      test('produces valid JSON', () {
        final resource = McpResource(
          uri: 'file:///test/path.txt',
          name: 'Test File',
          description: 'A test file',
          mimeType: 'text/plain',
        );
        final jsonString = jsonEncode(resource.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });
}
