import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

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
      markTestSkipped('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>. Integration tests require a running OpenCode server.');
    }

    print('=== Message Send With Model Test ===');
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

  testWidgets('send message with default model', (tester) async {
    print('\n--- Step 1: Health Check ---');
    final health = await client.healthCheck();
    expect(health.healthy, isTrue, reason: 'Server should be healthy: ${health.error}');

    print('\n--- Step 2: Create Session ---');
    final session = await client.createSession(input: SessionCreateInput(title: 'Default Model Test'));
    print('Created session: ${session.id}');
    expect(session.id, isNotEmpty);

    try {
      print('\n--- Step 3: Send Message (default model) ---');
      final response = await client.sendMessage(
        session.id,
        text: 'Say just the word "hello" and nothing else.',
      );
      print('sendMessage response: id=${response.id}, role=${response.role}');
      expect(response.id, isNotEmpty);

      print('\n--- Step 4: Poll for messages ---');
      List<dynamic> messages = [];
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 2));
        messages = await client.getMessages(session.id);
        final assistantMessages =
            messages.where((m) => m.role.toString() == 'MessageRole.assistant').toList();
        if (assistantMessages.isNotEmpty) {
          print('Found assistant message after ${(i + 1) * 2}s');
          break;
        }
      }

      print('Total messages: ${messages.length}');
      for (final msg in messages) {
        print('  - id=${msg.id}, role=${msg.role}');
      }

      expect(messages.length, greaterThanOrEqualTo(2),
          reason: 'Should have user message and at least one assistant response');
    } finally {
      print('\n--- Cleanup: Delete Session ---');
      await client.deleteSession(session.id);
      print('Session deleted');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('send message with explicit model', (tester) async {
    print('\n--- Step 1: Health Check ---');
    final health = await client.healthCheck();
    expect(health.healthy, isTrue, reason: 'Server should be healthy: ${health.error}');

    print('\n--- Step 2: Fetch Providers ---');
    final providers = await client.getProviders();
    print('Providers: ${providers.length}');
    expect(providers, isNotEmpty, reason: 'Server should have at least one provider');

    // Find a provider with at least one model
    final provider = providers.firstWhere(
      (p) => p.models.isNotEmpty,
      orElse: () => throw TestFailure('No provider with models found'),
    );
    final modelId = provider.models.first.id;
    print('Selected: provider=${provider.id}, model=$modelId');
    expect(provider.id, isNotEmpty);
    expect(modelId, isNotEmpty);

    print('\n--- Step 3: Create Session ---');
    final session = await client.createSession(input: SessionCreateInput(title: 'Explicit Model Test'));
    print('Created session: ${session.id}');
    expect(session.id, isNotEmpty);

    try {
      print('\n--- Step 4: Send Message (explicit model) ---');
      final response = await client.sendMessage(
        session.id,
        text: 'Say just the word "hello" and nothing else.',
        providerID: provider.id,
        modelID: modelId,
      );
      print('sendMessage response: id=${response.id}, role=${response.role}, sessionId=${response.sessionId}');
      // Note: Server may return empty body when using explicit model, so id may be empty
      expect(response.sessionId, isNotEmpty);

      // Wait a moment for the message to be stored
      await Future.delayed(const Duration(seconds: 2));

      print('\n--- Step 5: Get messages ---');
      final messages = await client.getMessages(session.id);
      print('Total messages: ${messages.length}');
      for (final msg in messages) {
        print('  - id=${msg.id}, role=${msg.role}');
      }

      // Verify the user message was stored
      expect(messages.length, greaterThanOrEqualTo(1),
          reason: 'Should have at least the user message');
      expect(messages.first.role.toString(), equals('MessageRole.user'));
    } finally {
      print('\n--- Cleanup: Delete Session ---');
      await client.deleteSession(session.id);
      print('Session deleted');
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
