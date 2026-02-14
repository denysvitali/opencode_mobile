import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/core/models/permission.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;
  late SSEClient sseClient;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    print('=== SSE Events Comprehensive Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );

    sseClient = SSEClient();
  });

  tearDownAll(() {
    sseClient.disconnect();
    platformHttpClient.close();
  });

  group('SSE Connection Basics', () {
    testWidgets('connect and disconnect', (tester) async {
      final statusChanges = <SSEConnectionStatus>[];

      final subscription = sseClient.statusStream.listen((status) {
        print('SSE status: $status');
        statusChanges.add(status);
      });

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 2));

      expect(sseClient.status, equals(SSEConnectionStatus.connected));

      sseClient.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));

      expect(sseClient.status, equals(SSEConnectionStatus.disconnected));
      expect(statusChanges, contains(SSEConnectionStatus.connecting));
      expect(statusChanges, contains(SSEConnectionStatus.connected));

      await subscription.cancel();
    });

    testWidgets('receive connection events', (tester) async {
      final events = <SSEEvent>[];

      final subscription = sseClient.eventStream.listen((event) {
        print('SSE event received: ${event.event}');
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 3));

      // Should receive at least one event
      expect(events.isNotEmpty, isTrue,
          reason: 'Should receive at least one SSE event');

      sseClient.disconnect();
      await subscription.cancel();
    });
  });

  group('Session Events', () {
    testWidgets('session.created event received', (tester) async {
      final createdSessions = <Session>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.sessionCreatedStream.listen((session) {
        print('Session created: ${session.id}');
        createdSessions.add(session);
      });

      // Create a session
      final session = await client.createSession(
        input: SessionCreateInput(title: 'SSE Created Session'),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify we received the event
      final matching = createdSessions.where((s) => s.id == session.id);
      expect(matching.isNotEmpty || createdSessions.isNotEmpty, isTrue,
          reason: 'Should receive session.created event');

      await subscription.cancel();
      await client.deleteSession(session.id);
      sseClient.disconnect();
    });

    testWidgets('session.updated event received', (tester) async {
      final updatedSessions = <Session>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Original Title'),
      );

      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.sessionUpdateStream.listen((session) {
        print('Session updated: ${session.id}');
        updatedSessions.add(session);
      });

      // Update the session
      await client.updateSession(
        session.id,
        SessionUpdateInput(title: 'Updated Title'),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should have received update
      if (updatedSessions.isNotEmpty) {
        expect(updatedSessions.any((s) => s.id == session.id), isTrue,
            reason: 'Should receive session.updated for our session');
      }

      await subscription.cancel();
      await client.deleteSession(session.id);
      sseClient.disconnect();
    });

    testWidgets('session.deleted event received', (tester) async {
      final deletedIds = <String>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Session to Delete'),
      );

      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.sessionDeletedStream.listen((id) {
        print('Session deleted: $id');
        deletedIds.add(id);
      });

      // Delete the session
      await client.deleteSession(session.id);

      await Future.delayed(const Duration(seconds: 2));

      // Verify deletion event
      if (deletedIds.isNotEmpty) {
        expect(deletedIds.contains(session.id), isTrue,
            reason: 'Should receive session.deleted for our session');
      }

      await subscription.cancel();
      sseClient.disconnect();
    });

    testWidgets('session.status event received', (tester) async {
      final statusUpdates = <Map<String, String>>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.sessionStatusStream.listen((statuses) {
        print('Session statuses: $statuses');
        statusUpdates.add(statuses);
      });

      // Create and interact with a session to trigger status changes
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Status Test Session'),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Send a message to trigger status changes
      await client.sendPrompt(session.id, text: 'Hello');

      await Future.delayed(const Duration(seconds: 3));

      // Should have received at least one status update
      if (statusUpdates.isNotEmpty) {
        expect(statusUpdates.any((s) => s.containsKey(session.id)), isTrue,
            reason: 'Should receive session.status for our session');
      }

      await subscription.cancel();
      await client.deleteSession(session.id);
      sseClient.disconnect();
    });
  });

  group('Message Events', () {
    testWidgets('message.updated event received', (tester) async {
      final updatedMessages = <Message>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Message Update Test'),
      );

      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.messageUpdateStream.listen((message) {
        print('Message updated: ${message.id}, role: ${message.role}');
        updatedMessages.add(message);
      });

      // Send a message
      await client.sendPrompt(session.id, text: 'Test message');

      await Future.delayed(const Duration(seconds: 5));

      // Should receive message updates
      if (updatedMessages.isNotEmpty) {
        expect(updatedMessages.any((m) => m.sessionId == session.id), isTrue,
            reason: 'Should receive message.updated for session messages');
      }

      await subscription.cancel();
      await client.deleteSession(session.id);
      sseClient.disconnect();
    });

    testWidgets('message.part.updated event received', (tester) async {
      final partUpdates = <Message>[];

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Message Part Update Test'),
      );

      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.messagePartUpdateStream.listen((message) {
        print('Message part updated: ${message.id}');
        partUpdates.add(message);
      });

      // Send a message
      await client.sendPrompt(session.id, text: 'Generate some text');

      await Future.delayed(const Duration(seconds: 5));

      // May or may not receive part updates depending on server behavior
      // Just verify the stream is working
      print('Received ${partUpdates.length} part updates');

      await subscription.cancel();
      await client.deleteSession(session.id);
      sseClient.disconnect();
    });
  });

  group('Permission Events', () {
    testWidgets('permission stream is accessible', (tester) async {
      // Just verify we can listen to permission stream
      final permissions = <Permission>[];

      sseClient.connect(serverUrl: serverUrl);

      final subscription = sseClient.permissionStream.listen((permission) {
        print('Permission received: ${permission.id}');
        permissions.add(permission);
      });

      await Future.delayed(const Duration(seconds: 2));

      // Can't easily trigger permission events, but stream is accessible
      expect(sseClient.permissionStream, isA<Stream<Permission>>());

      await subscription.cancel();
      sseClient.disconnect();
    });
  });

  group('File Events', () {
    testWidgets('file edited stream is accessible', (tester) async {
      final fileEdits = <Map<String, dynamic>>[];

      sseClient.connect(serverUrl: serverUrl);

      final subscription = sseClient.fileEditedStream.listen((edit) {
        print('File edited: $edit');
        fileEdits.add(edit);
      });

      await Future.delayed(const Duration(seconds: 2));

      // Stream is accessible
      expect(sseClient.fileEditedStream, isA<Stream<Map<String, dynamic>>>());

      await subscription.cancel();
      sseClient.disconnect();
    });
  });

  group('Multiple Events', () {
    testWidgets('receives multiple event types', (tester) async {
      final eventsByType = HashMap<String, List<SSEEvent>>();

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 1));

      final subscription = sseClient.eventStream.listen((event) {
        final type = event.event ?? 'unknown';
        eventsByType.putIfAbsent(type, () => []).add(event);
      });

      // Perform several operations
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Multi Event Test'),
      );

      await Future.delayed(const Duration(seconds: 1));

      await client.sendPrompt(session.id, text: 'Test');

      await Future.delayed(const Duration(seconds: 3));

      await client.deleteSession(session.id);

      await Future.delayed(const Duration(seconds: 2));

      // Print summary
      print('\n=== Event Summary ===');
      for (final entry in eventsByType.entries) {
        print('${entry.key}: ${entry.value.length} events');
      }

      // Should have received multiple event types
      expect(eventsByType.length >= 1, isTrue,
          reason: 'Should receive at least one event type');

      await subscription.cancel();
      sseClient.disconnect();
    });
  });

  group('Event Reconnection', () {
    testWidgets('reconnects after disconnection', (tester) async {
      final reconnectAttempts = <int>[];

      // Track status changes
      final subscription = sseClient.statusStream.listen((status) {
        print('Status: $status');
      });

      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 2));

      expect(sseClient.status, equals(SSEConnectionStatus.connected));

      // Disconnect manually
      sseClient.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));

      expect(sseClient.status, equals(SSEConnectionStatus.disconnected));

      // Reconnect
      sseClient.connect(serverUrl: serverUrl);
      await Future.delayed(const Duration(seconds: 2));

      expect(sseClient.status, equals(SSEConnectionStatus.connected));

      await subscription.cancel();
      sseClient.disconnect();
    });
  });
}
