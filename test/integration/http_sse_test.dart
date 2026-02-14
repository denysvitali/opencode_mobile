import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    print('=== SSE via HTTP Test ===');
    print('Server URL: $serverUrl');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  testWidgets('receive SSE events via HTTP/2', (tester) async {
    print('\n--- Step 1: Health Check ---');
    final health = await client.healthCheck();
    print('Health check: healthy=${health.healthy}, version=${health.version}, error=${health.error}');
    expect(health.healthy, isTrue, reason: 'Server should be healthy: ${health.error}');

    print('\n--- Step 2: Connect to SSE via HTTP ---');
    final events = <String>[];

    // Use HTTP client with streaming to receive SSE
    final baseUri = Uri.parse('$serverUrl/global/event');
    print('Connecting to: $baseUri');

    final request = http.Request('GET', baseUri);
    request.headers['Accept'] = 'text/event-stream';

    final response = await platformHttpClient.client.send(request);
    print('Response status: ${response.statusCode}');
    print('Response content-type: ${response.headers['content-type']}');

    expect(response.statusCode, equals(200));
    expect(response.headers['content-type'], contains('text/event-stream'));

    // Listen to SSE stream
    final completer = Completer<void>();
    String buffer = '';

    final subscription = response.stream.listen((chunk) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          print('SSE received: $data');
          events.add(data);

          if (data.contains('server.connected')) {
            completer.complete();
          }
        }
      }
    });

    // Wait for initial connection event
    try {
      await completer.future.timeout(const Duration(seconds: 10));
      print('Received server.connected event!');
    } catch (e) {
      print('Timeout waiting for server.connected event');
    }

    print('\n--- Step 3: Create session ---');
    final session = await client.createSession(input: SessionCreateInput(title: 'HTTP SSE Test'));
    print('Created session: ${session.id}');

    try {
      print('\n--- Step 4: Send message ---');
      await client.sendMessage(session.id, text: 'hello');
      print('Message sent');

      // Wait for message events
      await Future.delayed(const Duration(seconds: 5));

      print('\n--- Step 5: Events received ---');
      print('Total events: ${events.length}');
      for (final event in events) {
        print('  - $event');
      }

      // Check for message events
      final messageEvents = events.where((e) => e.contains('message.updated') || e.contains('message.part.updated')).toList();
      print('Message events: ${messageEvents.length}');

    } finally {
      print('\n--- Cleanup ---');
      await subscription.cancel();
      await client.deleteSession(session.id);
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
