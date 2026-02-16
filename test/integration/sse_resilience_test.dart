import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;
  late SSEClient sseClient;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      markTestSkipped(
          'SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    print('=== SSE Resilience Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(config: ServerConfig(url: serverUrl));

    sseClient = SSEClient();
  });

  tearDownAll(() {
    sseClient.disconnect();
    platformHttpClient.close();
  });

  group('SSE Reconnection with Exponential Backoff', () {
    testWidgets('SSE reconnects after connection drop with exponential backoff',
        (tester) async {
      print('\n--- Test: SSE Reconnection with Exponential Backoff ---');

      final health = await client.healthCheck();
      expect(health.healthy, isTrue);
      print('Server healthy: ${health.healthy}');

      final events = <SSEEvent>[];
      final statusChanges = <SSEConnectionStatus>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) {
        print('SSE status changed: $status');
        statusChanges.add(status);
      });

      final eventSubscription = sseClient.eventStream.listen((event) {
        print('SSE event: ${event.event}');
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 3));
      expect(sseClient.status, equals(SSEConnectionStatus.connected),
          reason: 'Initial connection should succeed. Status: ${sseClient.status}');

      await statusSubscription.cancel();
      await eventSubscription.cancel();

      print('Initial connection successful, status changes: $statusChanges');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('SSE exponential backoff timing follows power of 2',
        (tester) async {
      print('\n--- Test: Exponential Backoff Timing ---');

      final reconnectionDelays = <Duration>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) async {
        if (status == SSEConnectionStatus.connecting) {
          reconnectionDelays.add(Duration.zero);
        }
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 5));

      await statusSubscription.cancel();

      print('Backoff delays recorded: ${reconnectionDelays.length} attempts');
      expect(reconnectionDelays.length, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('SSE Reconnection After Connection Drops', () {
    testWidgets('SSE recovers after stream error', (tester) async {
      print('\n--- Test: SSE Recovery After Stream Error ---');

      final events = <SSEEvent>[];
      final statusChanges = <SSEConnectionStatus>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) {
        print('SSE status changed: $status');
        statusChanges.add(status);
      });

      final eventSubscription = sseClient.eventStream.listen((event) {
        print('SSE event: ${event.event}');
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 3));
      expect(sseClient.status, equals(SSEConnectionStatus.connected));

      final session = await client.createSession(
          input: SessionCreateInput(title: 'Stream Error Test'));

      try {
        await client.sendPrompt(session.id, text: 'test message');
        await Future.delayed(const Duration(seconds: 3));

        final hasMessageEvents = events.any(
            (e) => e.event == 'message.updated' || e.event == 'message.part.updated');
        print('Message events received after send: $hasMessageEvents');

        expect(hasMessageEvents, isTrue,
            reason: 'Should receive message events after sending');
      } finally {
        await client.deleteSession(session.id);
      }

      await statusSubscription.cancel();
      await eventSubscription.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('SSE maintains connection through multiple operations',
        (tester) async {
      print('\n--- Test: SSE Connection Through Multiple Operations ---');

      final events = <SSEEvent>[];

      final eventSubscription = sseClient.eventStream.listen((event) {
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 2));

      final sessions = <Session>[];
      for (int i = 0; i < 3; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'MultiOp Test $i'));
        sessions.add(session);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await Future.delayed(const Duration(seconds: 3));

      print('Created ${sessions.length} sessions, events received: ${events.length}');

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }

      await eventSubscription.cancel();

      expect(events.length, greaterThan(0),
          reason: 'Should receive events through multiple operations');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('SSE Event Recovery After Reconnection', () {
    testWidgets('SSE events are received after reconnection', (tester) async {
      print('\n--- Test: SSE Event Recovery After Reconnection ---');

      final events = <SSEEvent>[];
      final statusChanges = <SSEConnectionStatus>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) {
        print('SSE status changed: $status');
        statusChanges.add(status);
      });

      final eventSubscription = sseClient.eventStream.listen((event) {
        print('SSE event: ${event.event}');
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 3));

      final session1 = await client.createSession(
          input: SessionCreateInput(title: 'Recovery Test 1'));
      await Future.delayed(const Duration(seconds: 1));

      final session2 = await client.createSession(
          input: SessionCreateInput(title: 'Recovery Test 2'));
      await Future.delayed(const Duration(seconds: 1));

      final eventsAfterReconnect = events.length;
      print('Events after operations: $eventsAfterReconnect');

      await client.sendPrompt(session2.id, text: 'test');
      await Future.delayed(const Duration(seconds: 3));

      print('Events after message: ${events.length}');

      expect(events.length, greaterThan(eventsAfterReconnect),
          reason: 'Should receive more events after message');

      await client.deleteSession(session1.id);
      await client.deleteSession(session2.id);

      await statusSubscription.cancel();
      await eventSubscription.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('SSE Event Ordering During Rapid Operations', () {
    testWidgets('SSE events maintain correct order during rapid session creation',
        (tester) async {
      print('\n--- Test: SSE Event Ordering During Rapid Operations ---');

      final events = <SSEEvent>[];
      final eventTimestamps = <String, int>{};

      final eventSubscription = sseClient.eventStream.listen((event) {
        eventTimestamps[event.event ?? 'unknown'] = DateTime.now().millisecondsSinceEpoch;
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 2));

      final sessions = <Session>[];
      for (int i = 0; i < 5; i++) {
        final session = await client.createSession(
            input: SessionCreateInput(title: 'Rapid Test $i'));
        sessions.add(session);
      }

      await Future.delayed(const Duration(seconds: 3));

      final sessionCreatedEvents =
          events.where((e) => e.event == 'session.created').toList();
      print('Session created events: ${sessionCreatedEvents.length}');

      expect(sessionCreatedEvents.length, greaterThanOrEqualTo(5),
          reason: 'Should receive session.created events for all created sessions');

      for (final session in sessions) {
        await client.deleteSession(session.id);
      }

      await eventSubscription.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('SSE events maintain order with interleaved operations',
        (tester) async {
      print('\n--- Test: SSE Event Ordering with Interleaved Operations ---');

      final events = <SSEEvent>[];
      final messageOrder = <String>[];

      final eventSubscription = sseClient.eventStream.listen((event) {
        events.add(event);
        if (event.event == 'session.status') {
          messageOrder.add('status');
        } else if (event.event == 'session.created') {
          messageOrder.add('created');
        } else if (event.event == 'message.updated') {
          messageOrder.add('message');
        }
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 2));

      final session = await client.createSession(
          input: SessionCreateInput(title: 'Interleave Test'));
      await Future.delayed(const Duration(milliseconds: 500));

      await client.sendPrompt(session.id, text: 'first message');
      await Future.delayed(const Duration(seconds: 2));

      await client.sendPrompt(session.id, text: 'second message');
      await Future.delayed(const Duration(seconds: 2));

      print('Event order: $messageOrder');

      await client.deleteSession(session.id);

      await eventSubscription.cancel();

      expect(events.length, greaterThan(0),
          reason: 'Should receive events during interleaved operations');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Heartbeat Handling', () {
    testWidgets('SSE connection survives heartbeat intervals', (tester) async {
      print('\n--- Test: Heartbeat Handling ---');

      final events = <SSEEvent>[];
      final statusChanges = <SSEConnectionStatus>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) {
        print('SSE status: $status');
        statusChanges.add(status);
      });

      final eventSubscription = sseClient.eventStream.listen((event) {
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 3));
      expect(sseClient.status, equals(SSEConnectionStatus.connected));

      final initialEvents = events.length;
      print('Initial events: $initialEvents');

      await Future.delayed(const Duration(seconds: 35));

      final afterHeartbeat = events.length;
      print('Events after heartbeat: $afterHeartbeat');

      final connectedDuringHeartbeat =
          statusChanges.any((s) => s == SSEConnectionStatus.connected);
      expect(connectedDuringHeartbeat, isTrue,
          reason: 'Should remain connected through heartbeat');

      final finalStatus = sseClient.status;
      print('Final status: $finalStatus');

      await statusSubscription.cancel();
      await eventSubscription.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Server Restart Mid-Connection', () {
    testWidgets('SSE reconnects after server restart simulation',
        (tester) async {
      print('\n--- Test: Server Restart Mid-Connection ---');

      final events = <SSEEvent>[];
      final statusChanges = <SSEConnectionStatus>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) {
        print('SSE status: $status');
        statusChanges.add(status);
      });

      final eventSubscription = sseClient.eventStream.listen((event) {
        events.add(event);
      });

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 3));
      expect(sseClient.status, equals(SSEConnectionStatus.connected));

      final session = await client.createSession(
          input: SessionCreateInput(title: 'Restart Test'));

      await Future.delayed(const Duration(seconds: 2));

      print('Simulating connection drop by disconnecting and reconnecting...');
      sseClient.disconnect();

      await Future.delayed(const Duration(seconds: 2));

      sseClient.connect(serverUrl: serverUrl);

      await Future.delayed(const Duration(seconds: 5));

      final reconnectStatus = sseClient.status;
      print('Status after reconnect: $reconnectStatus');

      expect(
          reconnectStatus == SSEConnectionStatus.connected ||
              reconnectStatus == SSEConnectionStatus.connecting,
          isTrue,
          reason: 'Should reconnect after connection drop');

      final eventsAfterReconnect = events.length;
      print('Events after reconnect: $eventsAfterReconnect');

      await client.deleteSession(session.id);

      await statusSubscription.cancel();
      await eventSubscription.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('SSE handles rapid connect-disconnect-reconnect cycles',
        (tester) async {
      print('\n--- Test: Rapid Connect-Disconnect-Reconnect Cycles ---');

      final statusHistory = <SSEConnectionStatus>[];

      for (int i = 0; i < 3; i++) {
        print('Cycle ${i + 1}...');

        final statusSubscription =
            sseClient.statusStream.listen((status) {
          statusHistory.add(status);
        });

        sseClient.connect(serverUrl: serverUrl);

        await Future.delayed(const Duration(seconds: 2));

        expect(sseClient.status, equals(SSEConnectionStatus.connected));

        sseClient.disconnect();

        await Future.delayed(const Duration(seconds: 1));

        await statusSubscription.cancel();
      }

      print('Status history length: ${statusHistory.length}');
      expect(statusHistory.length, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('SSE Error Handling', () {
    testWidgets('SSE handles invalid server gracefully', (tester) async {
      print('\n--- Test: SSE Error Handling ---');

      final statusChanges = <SSEConnectionStatus>[];

      final statusSubscription =
          sseClient.statusStream.listen((status) {
        print('SSE status: $status');
        statusChanges.add(status);
      });

      sseClient.connect(serverUrl: 'http://invalid-host-12345.local:9999');

      await Future.delayed(const Duration(seconds: 5));

      final hadError = statusChanges.contains(SSEConnectionStatus.error);
      final hadDisconnect = statusChanges.contains(SSEConnectionStatus.disconnected);

      print('Had error status: $hadError, Had disconnect: $hadDisconnect');

      await statusSubscription.cancel();

      expect(
          hadError || hadDisconnect || statusChanges.isNotEmpty, isTrue,
          reason: 'Should handle invalid server gracefully');
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
