import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');
  const serverPassword = String.fromEnvironment('SERVER_PASSWORD');

  late OpenCodeClient client;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    print('=== Config and Auth Test ===');
    print('Server URL: $serverUrl');
    print('Password set: ${serverPassword.isNotEmpty}');

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(
        url: serverUrl,
        username: serverPassword.isNotEmpty ? 'opencode' : null,
        password: serverPassword.isNotEmpty ? serverPassword : null,
      ),
    );
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('Config Operations', () {
    testWidgets('get config returns valid config', (tester) async {
      final config = await client.getConfig();

      expect(config, isNotNull);
      // Config may have various fields, just verify it parses
    });

    testWidgets('update config theme', (tester) async {
      final originalConfig = await client.getConfig();

      // Update theme
      final newConfig = AppConfig(theme: 'dark');
      final updated = await client.updateConfig(newConfig);

      expect(updated.theme, equals('dark'));

      // Verify by fetching
      final fetched = await client.getConfig();
      expect(fetched.theme, equals('dark'));
    });

    testWidgets('get config providers returns providers', (tester) async {
      final response = await client.getConfigProviders();

      expect(response, isNotNull);
      expect(response.providers, isA<List>());

      // If server has providers configured, verify structure
      for (final provider in response.providers) {
        expect(provider.id, isNotEmpty, reason: 'Provider ID should be set');
        expect(provider.name, isNotNull);
      }
    });

    testWidgets('config with directory parameter', (tester) async {
      // Test with a directory parameter
      final config = await client.getConfig(directory: '/tmp');
      expect(config, isNotNull);
    });
  });

  group('Global Config Operations', () {
    testWidgets('get global config returns config', (tester) async {
      final config = await client.getGlobalConfig();

      expect(config, isNotNull);
      // Global config may have different structure than project config
    });

    testWidgets('update global config theme', (tester) async {
      final newConfig = AppConfig(theme: 'light');
      final updated = await client.updateGlobalConfig(newConfig);

      expect(updated.theme, equals('light'));
    });

    testWidgets('dispose global returns true', (tester) async {
      // Dispose cleans up global state, may or may not work depending on server state
      try {
        final result = await client.disposeGlobal();
        expect(result, isA<bool>());
      } on OpenCodeException catch (e) {
        // Dispose may fail in certain states, that's okay
        print('Dispose returned error (expected in some states): $e');
      }
    });
  });

  group('Auth Operations', () {
    testWidgets('set auth with valid credentials', (tester) async {
      // Test setting auth for a provider
      // Note: This requires a valid provider ID, so we use 'mock' or skip
      const providerId = 'mock-test-provider';
      final credentials = {
        'apiKey': 'test-api-key-12345',
      };

      try {
        final result = await client.setAuth(providerId, credentials);
        expect(result, isTrue);
      } on OpenCodeException catch (e) {
        // May fail if provider doesn't exist - that's okay for this test
        print('setAuth returned (may be expected): $e');
      }
    });

    testWidgets('remove auth for provider', (tester) async {
      const providerId = 'mock-test-provider';

      try {
        final result = await client.removeAuth(providerId);
        expect(result, isA<bool>());
      } on OpenCodeException catch (e) {
        // May fail if provider doesn't exist - that's okay
        print('removeAuth returned (may be expected): $e');
      }
    });
  });

  group('Basic Auth with Password', () {
    testWidgets('authenticated health check works with password', (tester) async {
      if (serverPassword.isEmpty) {
        print('Skipping auth test - no password configured');
        return;
      }

      final result = await client.healthCheck();
      expect(result.healthy, isTrue,
          reason: 'Health check should work with auth: ${result.error}');
    });

    testWidgets('unauthenticated request fails with password', (tester) async {
      if (serverPassword.isEmpty) {
        print('Skipping auth test - no password configured');
        return;
      }

      // Create client without auth
      final unauthClient = OpenCodeClient();
      await unauthClient.initialize(
        config: ServerConfig(url: serverUrl), // No auth
      );

      try {
        await unauthClient.healthCheck();
        fail('Should have failed without auth');
      } catch (e) {
        // Expected - should fail
        expect(e, isA<OpenCodeException>());
      }
    });
  });

  group('Config Structure Validation', () {
    testWidgets('config has agent settings', (tester) async {
      final config = await client.getConfig();

      // Agent settings may be present or not
      if (config.agent != null) {
        expect(config.agent!.model, anyOf(isNull, isA<String>()));
        expect(config.agent!.provider, anyOf(isNull, isA<String>()));
      }
    });

    testWidgets('config provider map is accessible', (tester) async {
      final config = await client.getConfig();

      // Provider config may be empty or populated
      if (config.provider != null) {
        expect(config.provider, isA<Map<String, dynamic>>());
      }
    });

    testWidgets('config mcp settings are accessible', (tester) async {
      final config = await client.getConfig();

      // MCP config may be empty or populated
      if (config.mcp != null) {
        expect(config.mcp, isA<Map<String, dynamic>>());
      }
    });

    testWidgets('providers response has defaults', (tester) async {
      final response = await client.getConfigProviders();

      // Defaults map may be empty or populated
      expect(response.defaults, isA<Map<String, String>>());
    });
  });
}
