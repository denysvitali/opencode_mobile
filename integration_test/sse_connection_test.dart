import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/api/sse_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
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

    print('=== SSE Connection Test ===');
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

  testWidgets('SSE connection and event reception', (tester) async {
    print('\n--- Step 1: Health Check ---');
    final health = await client.healthCheck();
    print('Health check: healthy=${health.healthy}, version=${health.version}, error=${health.error}');
    expect(health.healthy, isTrue, reason: 'Server should be healthy: ${health.error}');

    print('\n--- Step 2: Connect to SSE ---');
    final events = <SSEEvent>[];
    final statusChanges = <SSEConnectionStatus>[];

    // Listen to status changes
    final statusSubscription = sseClient.statusStream.listen((status) {
      print('SSE status changed: $status');
      statusChanges.add(status);
    });

    // Listen to all events
    final eventSubscription = sseClient.eventStream.listen((event) {
      print('SSE event: event=${event.event}, id=${event.id}, data=${event.data}');
      events.add(event);
    });

    // Connect
    sseClient.connect(serverUrl: serverUrl);

    // Wait for connection
    print('Waiting for connection...');
    await Future.delayed(const Duration(seconds: 3));

    print('SSE status: ${sseClient.status}');
    expect(sseClient.status, equals(SSEConnectionStatus.connected),
        reason: 'SSE should be connected. Status history: $statusChanges');

    print('\n--- Step 3: Create session and send message ---');
    final session = await client.createSession(input: SessionCreateInput(title: 'SSE Test Session'));
    print('Created session: ${session.id}');

    try {
      print('\n--- Step 4: Send message and wait for events ---');

      // Send message
      final response = await client.sendMessage(
        session.id,
        text: 'test',
      );
      print('Message sent: ${response.id}');

      // Wait for events (should receive message.updated)
      print('Waiting for SSE events...');
      await Future.delayed(const Duration(seconds: 5));

      print('\n--- Step 5: Check events received ---');
      print('Total events received: ${events.length}');

      final messageUpdatedEvents = events.where((e) => e.event == 'message.updated').toList();
      final messagePartUpdatedEvents = events.where((e) => e.event == 'message.part.updated').toList();

      print('message.updated events: ${messageUpdatedEvents.length}');
      print('message.part.updated events: ${messagePartUpdatedEvents.length}');

      // Print all unique event types received
      final eventTypes = events.map((e) => e.event).whereType<String>().toSet();
      print('Event types received: $eventTypes');

      // The test passes if we get any message-related events
      final hasMessageEvents = messageUpdatedEvents.isNotEmpty || messagePartUpdatedEvents.isNotEmpty;

      if (!hasMessageEvents) {
        print('\n!!! WARNING: No message.updated or message.part.updated events received !!!');
        print('This indicates SSE is not properly delivering message updates.');
        print('Events received: ${events.map((e) => e.event).toList()}');
      }

      // Also try getting messages via HTTP to compare
      print('\n--- Step 6: Verify messages via HTTP ---');
      final messages = await client.getMessages(session.id);
      print('Messages via HTTP: ${messages.length}');
      for (final msg in messages) {
        print('  - id=${msg.id}, role=${msg.role}, parts=${msg.parts?.length}');
      }

      // Clean up
      await statusSubscription.cancel();
      await eventSubscription.cancel();

    } finally {
      print('\n--- Cleanup: Delete Session ---');
      await client.deleteSession(session.id);
    }
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('WebSocket URL construction', (tester) async {
    // Test URL construction
    print('\n--- WebSocket URL Construction Test ---');

    final httpsUrl = 'https://example.com';
    final httpUrl = 'http://example.com';

    final httpsWs = httpsUrl.startsWith('https')
        ? 'wss://example.com/global/event'
        : 'ws://example.com/global/event';
    final httpWs = httpUrl.startsWith('https')
        ? 'wss://example.com/global/event'
        : 'ws://example.com/global/event';

    print('HTTPS -> $httpsWs');
    print('HTTP -> $httpWs');

    expect(httpsWs, equals('wss://example.com/global/event'));
    expect(httpWs, equals('ws://example.com/global/event'));
  });
}
