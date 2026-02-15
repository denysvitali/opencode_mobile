import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/core/models/provider.dart';
import 'package:opencode_mobile/core/models/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(config: ServerConfig(url: serverUrl));
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('Provider and Model Discovery', () {
    testWidgets('getConfigProviders returns structured data', (tester) async {
      final response = await client.getConfigProviders();

      expect(response.providers, isNotEmpty);

      for (final provider in response.providers) {
        expect(provider.id, isNotEmpty, reason: 'Provider id must not be empty');
        expect(provider.name, isNotEmpty, reason: 'Provider name must not be empty');

        for (final model in provider.models) {
          expect(model.id, isNotEmpty, reason: 'Model id must not be empty');
          expect(model.name, isNotEmpty, reason: 'Model name must not be empty');
        }
      }

      // defaults map should exist (can be empty)
      expect(response.defaults, isA<Map<String, String>>());
    });

    testWidgets('configured providers have at least one model', (tester) async {
      final response = await client.getConfigProviders();

      final configured =
          response.providers.where((p) => p.configured).toList();

      for (final provider in configured) {
        expect(
          provider.models,
          isNotEmpty,
          reason: 'Configured provider ${provider.id} should have models',
        );
      }
    });
  });

  group('Message with Model Selection', () {
    Provider? findConfiguredProvider(ProvidersResponse response) {
      try {
        return response.providers.firstWhere(
          (p) => p.configured && p.models.isNotEmpty,
        );
      } catch (_) {
        return null;
      }
    }

    testWidgets('send message with explicit provider/model', (tester) async {
      final providers = await client.getConfigProviders();
      final provider = findConfiguredProvider(providers);

      if (provider == null) {
        // Skip if no configured provider with models
        return;
      }

      final model = provider.models.first;

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Explicit Model Test'),
      );

      try {
        await client.sendPrompt(
          session.id,
          text: 'Reply with: "model selection works"',
          providerID: provider.id,
          modelID: model.id,
        );

        // Poll for assistant response
        var messages = <Message>[];
        for (var i = 0; i < 30; i++) {
          await Future.delayed(const Duration(seconds: 2));
          messages = await client.getMessages(session.id);
          if (messages.any((m) => m.role == MessageRole.assistant)) break;
        }

        expect(
          messages.any((m) => m.role == MessageRole.assistant),
          isTrue,
          reason: 'Should receive assistant response with explicit model',
        );
      } finally {
        try {
          await client.deleteSession(session.id);
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('send message with default model (no provider/model)',
        (tester) async {
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Default Model Test'),
      );

      try {
        await client.sendPrompt(
          session.id,
          text: 'Reply with: "default model works"',
        );

        // Poll for assistant response
        var messages = <Message>[];
        for (var i = 0; i < 30; i++) {
          await Future.delayed(const Duration(seconds: 2));
          messages = await client.getMessages(session.id);
          if (messages.any((m) => m.role == MessageRole.assistant)) break;
        }

        expect(
          messages.any((m) => m.role == MessageRole.assistant),
          isTrue,
          reason: 'Should receive assistant response with default model',
        );
      } finally {
        try {
          await client.deleteSession(session.id);
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('stream message with explicit model', (tester) async {
      final providers = await client.getConfigProviders();
      final provider = findConfiguredProvider(providers);

      if (provider == null) {
        return;
      }

      final model = provider.models.first;

      final session = await client.createSession(
        input: SessionCreateInput(title: 'Stream Model Test'),
      );

      try {
        final streamMessages = <Message>[];

        await for (final msg in client.sendPromptStream(
          session.id,
          text: 'Reply with: "streaming works"',
          providerID: provider.id,
          modelID: model.id,
        )) {
          streamMessages.add(msg);
        }

        expect(streamMessages, isNotEmpty,
            reason: 'Stream should yield messages');

        for (final msg in streamMessages) {
          if (msg.sessionId.isNotEmpty) {
            expect(msg.sessionId, equals(session.id));
          }
        }
      } finally {
        try {
          await client.deleteSession(session.id);
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Model Iteration', () {
    testWidgets('all configured providers have valid model metadata',
        (tester) async {
      final response = await client.getConfigProviders();

      // No duplicate provider IDs
      final providerIds = response.providers.map((p) => p.id).toList();
      expect(
        providerIds.toSet().length,
        equals(providerIds.length),
        reason: 'Provider IDs should be unique',
      );

      for (final provider in response.providers) {
        // No duplicate model IDs within a provider
        final modelIds = provider.models.map((m) => m.id).toList();
        expect(
          modelIds.toSet().length,
          equals(modelIds.length),
          reason: 'Model IDs should be unique within provider ${provider.id}',
        );

        for (final model in provider.models) {
          expect(model.id, isNotEmpty);
          expect(model.name, isNotEmpty);
        }
      }
    });
  });
}
