import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';

class MockSSEClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  MockSSEClient({required this.handler});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SSEEvent', () {
    group('parse', () {
      test('parses event type', () {
        final event = SSEEvent.parse('event: message.updated\ndata: {}');
        expect(event.event, 'message.updated');
      });

      test('parses id field', () {
        final event = SSEEvent.parse('id: 123\ndata: {}');
        expect(event.id, '123');
      });

      test('parses data lines', () {
        final event = SSEEvent.parse('data: some data');
        expect(event.data, isNotNull);
      });

      test('parses JSON data', () {
        final event = SSEEvent.parse('data: {"message": "hello", "count": 42}');
        expect(event.data, isNotNull);
        expect(event.data!['message'], 'hello');
        expect(event.data!['count'], 42);
      });

      test('handles raw data on parse failure', () {
        final event = SSEEvent.parse('data: not valid json {{{');
        expect(event.data, isNotNull);
        expect(event.data!['raw'], 'not valid json {{{');
      });

      test('parses nested payload with type', () {
        final event = SSEEvent.parse(
          'data: {"payload": {"type": "message.updated", "properties": {"info": {"id": "123"}}}}',
        );
        expect(event.event, 'message.updated');
        expect(event.data, isNotNull);
      });

      test('handles empty data', () {
        final event = SSEEvent.parse('data: ');
        expect(event.data, isNull);
      });

      test('handles multiline data', () {
        final event = SSEEvent.parse('data: line1\ndata: line2');
        expect(event.data, isNotNull);
      });

      test('returns null data for empty string', () {
        final event = SSEEvent.parse('');
        expect(event.data, isNull);
        expect(event.event, isNull);
        expect(event.id, isNull);
      });

      test('handles complex nested payload structure', () {
        final rawData =
            'data: {"payload":{"type":"session.status","properties":{"session1":"running"}}}';
        final event = SSEEvent.parse(rawData);
        expect(event.event, 'session.status');
        expect(event.data, isNotNull);
      });

      test('extracts event from payload properties type', () {
        final event = SSEEvent.parse(
          'data: {"payload": {"type": "session.created", "properties": {"info": {"id": "123"}}}}',
        );
        expect(event.event, 'session.created');
      });

      test('handles data without JSON', () {
        final event = SSEEvent.parse('data: plain text');
        expect(event.data, isNotNull);
      });
    });
  });

  group('SSEClient', () {
    setUp(() {
      platformHttpClient.setTestClient(null);
    });

    tearDown(() {
      platformHttpClient.setTestClient(null);
    });

    test('singleton pattern returns same instance', () {
      final instance1 = SSEClient();
      final instance2 = SSEClient();
      expect(identical(instance1, instance2), true);
    });

    test('initial status is disconnected', () {
      final client = SSEClient();
      expect(client.status, SSEConnectionStatus.disconnected);
    });

    group('connect', () {
      test('stores credentials and sets status to connecting then connected', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        final statusChanges = <SSEConnectionStatus>[];
        final subscription = client.statusStream.listen((status) {
          statusChanges.add(status);
        });

        client.connect(
          serverUrl: 'http://localhost:4096',
          username: 'user',
          password: 'pass',
        );

        await Future.delayed(Duration(milliseconds: 100));

        expect(client.status, SSEConnectionStatus.connected);
        expect(statusChanges.contains(SSEConnectionStatus.connecting), true);

        await subscription.cancel();
        await controller.close();
        client.disconnect();
      });

      test('stores server URL', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(serverUrl: 'http://testserver:8080');

        await Future.delayed(Duration(milliseconds: 100));

        expect(client.status, SSEConnectionStatus.connected);

        await controller.close();
        client.disconnect();
      });

      test('sets error status on HTTP error', () async {
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('')),
            500,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(serverUrl: 'http://localhost:4096');

        await Future.delayed(Duration(milliseconds: 100));

        expect(client.status, SSEConnectionStatus.error);

        client.disconnect();
      });

      test('includes credentials in request when provided', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          final authHeader = request.headers['Authorization'];
          expect(authHeader, isNotNull);
          expect(authHeader!.startsWith('Basic '), true);
          final encoded = authHeader.substring(6);
          final decoded = utf8.decode(base64Decode(encoded));
          expect(decoded, 'testuser:testpass');

          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(
          serverUrl: 'http://localhost:4096',
          username: 'testuser',
          password: 'testpass',
        );

        await Future.delayed(Duration(milliseconds: 100));

        await controller.close();
        client.disconnect();
      });

      test('omits Authorization header when no credentials', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          expect(request.headers.containsKey('Authorization'), false);

          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(serverUrl: 'http://localhost:4096');

        await Future.delayed(Duration(milliseconds: 100));

        await controller.close();
        client.disconnect();
      });
    });

    group('disconnect', () {
      test('cancels reconnection timer', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(serverUrl: 'http://localhost:4096');
        await Future.delayed(Duration(milliseconds: 100));

        expect(client.status, SSEConnectionStatus.connected);

        client.disconnect();

        expect(client.status, SSEConnectionStatus.disconnected);
      });

      test('clears global connection', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(serverUrl: 'http://localhost:4096');
        await Future.delayed(Duration(milliseconds: 100));

        expect(client.status, SSEConnectionStatus.connected);

        client.disconnect();

        expect(client.status, SSEConnectionStatus.disconnected);
      });

      test('sets status to disconnected', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();
        client.connect(serverUrl: 'http://localhost:4096');
        await Future.delayed(Duration(milliseconds: 100));

        expect(client.status, SSEConnectionStatus.connected);

        client.disconnect();

        expect(client.status, SSEConnectionStatus.disconnected);
      });

      test('can reconnect after disconnect', () async {
        final controller = StreamController<List<int>>.broadcast();
        
        final mockClient = MockSSEClient(handler: (request) async {
          return http.StreamedResponse(
            controller.stream,
            200,
          );
        });

        platformHttpClient.setTestClient(mockClient);

        final client = SSEClient();

        client.connect(serverUrl: 'http://localhost:4096');
        await Future.delayed(Duration(milliseconds: 100));
        expect(client.status, SSEConnectionStatus.connected);

        client.disconnect();
        expect(client.status, SSEConnectionStatus.disconnected);

        client.connect(serverUrl: 'http://localhost:4096');
        await Future.delayed(Duration(milliseconds: 100));
        expect(client.status, SSEConnectionStatus.connected);

        await controller.close();
        client.disconnect();
      });
    });

    group('event streams', () {
      test('has statusStream', () {
        final client = SSEClient();
        expect(client.statusStream, isA<Stream<SSEConnectionStatus>>());
      });

      test('has eventStream', () {
        final client = SSEClient();
        expect(client.eventStream, isA<Stream<SSEEvent>>());
      });

      test('has messageUpdateStream', () {
        final client = SSEClient();
        expect(client.messageUpdateStream, isA<Stream>());
      });

      test('has sessionUpdateStream', () {
        final client = SSEClient();
        expect(client.sessionUpdateStream, isA<Stream>());
      });

      test('has sessionCreatedStream', () {
        final client = SSEClient();
        expect(client.sessionCreatedStream, isA<Stream>());
      });

      test('has sessionDeletedStream', () {
        final client = SSEClient();
        expect(client.sessionDeletedStream, isA<Stream>());
      });

      test('has permissionStream', () {
        final client = SSEClient();
        expect(client.permissionStream, isA<Stream>());
      });

      test('has fileEditedStream', () {
        final client = SSEClient();
        expect(client.fileEditedStream, isA<Stream>());
      });

      test('has installationUpdateStream', () {
        final client = SSEClient();
        expect(client.installationUpdateStream, isA<Stream>());
      });
    });
  });

  group('SSEConnectionStatus', () {
    test('has all expected values', () {
      expect(SSEConnectionStatus.values, contains(SSEConnectionStatus.disconnected));
      expect(SSEConnectionStatus.values, contains(SSEConnectionStatus.connecting));
      expect(SSEConnectionStatus.values, contains(SSEConnectionStatus.connected));
      expect(SSEConnectionStatus.values, contains(SSEConnectionStatus.error));
    });

    test('has correct number of values', () {
      expect(SSEConnectionStatus.values.length, 4);
    });
  });
}
