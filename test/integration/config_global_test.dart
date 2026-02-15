import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';

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

  group('Health and Global', () {
    testWidgets('health check returns version', (tester) async {
      final result = await client.healthCheck();

      expect(result.healthy, isTrue);
      expect(result.version, isNotNull);
      expect(result.version, isNotEmpty);
      expect(result.error, isNull);
    });

    testWidgets('getGlobalConfig returns config', (tester) async {
      final config = await client.getGlobalConfig();

      expect(config, isA<AppConfig>());
      // Should not crash — config fields may be null but object is valid
    });

    testWidgets('getConfig returns config', (tester) async {
      final config = await client.getConfig();

      expect(config, isA<AppConfig>());
    });
  });

  group('Tool Discovery', () {
    testWidgets('getToolIds returns tool list', (tester) async {
      try {
        final ids = await client.getToolIds();

        expect(ids, isList);
        for (final id in ids) {
          expect(id, isNotEmpty, reason: 'Tool ID should not be empty');
        }
      } on OpenCodeException catch (e) {
        // Experimental endpoint — may not be available
        markTestSkipped('getToolIds not available: $e');
      }
    });

    testWidgets('getTools returns tools with schemas', (tester) async {
      try {
        final providers = await client.getConfigProviders();
        final configured =
            providers.providers.where((p) => p.configured && p.models.isNotEmpty);

        if (configured.isEmpty) {
          markTestSkipped('No configured provider with models');
          return;
        }

        final provider = configured.first;
        final model = provider.models.first;

        final toolList = await client.getTools(
          provider: provider.id,
          model: model.id,
        );

        expect(toolList.tools, isNotEmpty);

        for (final tool in toolList.tools) {
          expect(tool.name, isNotEmpty, reason: 'Tool name must not be empty');
          // inputSchema may be null for some tools, but name is required
        }
      } on OpenCodeException catch (e) {
        // Experimental endpoint — may not be available
        markTestSkipped('getTools not available: $e');
      }
    });
  });
}
