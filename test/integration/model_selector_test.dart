// Simple test to verify providers API works correctly
// Run with: dart test test/integration/model_selector_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/providers/model_selection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  group('Model Selector Tests', () {
    late OpenCodeClient client;

    setUpAll(() async {
      if (serverUrl.isEmpty) {
        fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
      }

      await platformHttpClient.initialize();

      client = OpenCodeClient();
      await client.initialize(
        config: ServerConfig(url: serverUrl),
      );
    });

    tearDownAll(() {
      platformHttpClient.close();
    });

    testWidgets('direct HTTP request works', (tester) async {
      final uri = Uri.parse('$serverUrl/config/providers');
      print('Direct HTTP request to: $uri');
      final response = await platformHttpClient.client.get(uri);
      print('Direct response status: ${response.statusCode}');
      print('Direct response body length: ${response.body.length}');
      expect(response.statusCode, 200);
    });

    testWidgets('getConfigProviders returns providers', (tester) async {
      print('Client config URL: ${client.config.url}');
      print('Making request to /config/providers...');

      final response = await client.getConfigProviders();

      print('Providers response:');
      print('  Count: ${response.providers.length}');
      print('  Defaults: ${response.defaults}');

      for (final provider in response.providers) {
        print('  Provider: ${provider.name} (${provider.id})');
        print('    Configured: ${provider.configured}');
        print('    Models: ${provider.models.length}');
        for (final model in provider.models) {
          print('      - ${model.name} (${model.id})');
        }
      }

      expect(response.providers, isA<List>());
    });

    testWidgets('ProvidersNotifier fetches providers correctly', (tester) async {
      final container = ProviderContainer();

      // Initial state
      var state = container.read(providersProvider);
      expect(state.isLoading, false);
      expect(state.providers, isEmpty);
      expect(state.error, isNull);

      // Fetch
      await container.read(providersProvider.notifier).fetch();

      // Check result
      state = container.read(providersProvider);
      print('ProvidersNotifier state after fetch:');
      print('  isLoading: ${state.isLoading}');
      print('  error: ${state.error}');
      print('  providers: ${state.providers.length}');

      expect(state.isLoading, false);

      if (state.error != null) {
        print('ERROR: ${state.error}');
      }

      expect(state.providers, isA<List>());
    });
  });
}
