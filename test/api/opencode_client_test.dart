import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenCodeClient', () {
    setUp(() {
      platformHttpClient.setTestClient(null);
    });

    tearDown(() {
      platformHttpClient.setTestClient(null);
    });

    group('_buildHeaders', () {
      test('includes Content-Type, User-Agent, Accept', () async {
        final mockClient = MockClient((request) async {
          expect(request.headers['Content-Type'], 'application/json');
          expect(request.headers['User-Agent'], 'OpenCodeMobile/1.0');
          expect(request.headers['Accept'], 'application/json');
          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        await client.healthCheck();
      });

      test('includes Basic Auth when config has credentials', () async {
        final mockClient = MockClient((request) async {
          final authHeader = request.headers['Authorization'];
          expect(authHeader, isNotNull);
          expect(authHeader!.startsWith('Basic '), true);

          final encoded = authHeader.substring(6);
          final decoded = utf8.decode(base64Decode(encoded));
          expect(decoded, 'user:pass123');

          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(
          url: 'http://localhost:4096',
          username: 'user',
          password: 'pass123',
        ));

        await client.healthCheck();
      });

      test('omits Authorization when no auth configured', () async {
        final mockClient = MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), false);
          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        await client.healthCheck();
      });
    });

    group('_buildUri', () {
      test('constructs correct URIs with path', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/project');
          return http.Response('[]', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096/api'));

        await client.listProjects();
      });

      test('handles query parameters', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('directory=%252Ftest%252Fpath'));
          return http.Response('[]', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        await client.listProjects(directory: '/test/path');
      });

      test('encodes special characters in query parameters', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('search=hello%2520world'));
          return http.Response('[]', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        await client.listSessions(search: 'hello world');
      });

      test('handles base URL with trailing slash', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/global/health');
          return http.Response('{"healthy": true}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096/'));

        await client.healthCheck();
      });

      test('handles base URL with path prefix', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/global/health');
          return http.Response('{"healthy": true}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096/api'));

        await client.healthCheck();
      });
    });

    group('_isSuccess', () {
      test('returns true for 2xx status codes', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, true);
        expect(result.error, isNull);
      });

      test('returns false for non-2xx status codes - 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, 'Server returned 404');
      });

      test('returns false for status code 500', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, 'Server returned 500');
      });

      test('returns false for status code 401', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, 'Server returned 401');
      });

      test('returns false for status code 300', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Multiple Choices', 300);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, 'Server returned 300');
      });
    });

    group('setServerConfig', () {
      test('updates internal config', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        expect(client.config.url, 'http://localhost:4096');
        expect(client.config.hasAuth, false);

        await client.setServerConfig(ServerConfig(
          url: 'http://newserver:8080',
          username: 'user',
          password: 'pass',
        ));

        expect(client.config.url, 'http://newserver:8080');
        expect(client.config.hasAuth, true);
        expect(client.config.username, 'user');
        expect(client.config.password, 'pass');
      });

      test('new credentials are used in subsequent requests', () async {
        var firstRequest = true;

        final mockClient = MockClient((request) async {
          if (firstRequest) {
            firstRequest = false;
            final authHeader = request.headers['Authorization'];
            expect(authHeader, isNotNull);
            expect(authHeader!.startsWith('Basic '), true);
            final encoded = authHeader.substring(6);
            final decoded = utf8.decode(base64Decode(encoded));
            expect(decoded, 'newuser:newpass');
          }
          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(
          url: 'http://localhost:4096',
          username: 'olduser',
          password: 'oldpass',
        ));

        await client.healthCheck();

        await client.setServerConfig(ServerConfig(
          url: 'http://localhost:4096',
          username: 'newuser',
          password: 'newpass',
        ));

        await client.healthCheck();
      });
    });

    group('_ensureInitialized', () {
      test('returns error when config.url is empty', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: ''));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, contains('not initialized'));
      });

      test('throws when not initialized at all', () async {
        final client = OpenCodeClient();

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, contains('not initialized'));
      });
    });

    group('OpenCodeException', () {
      test('toString formats message correctly', () {
        final exception = OpenCodeException('Test error message');
        expect(exception.toString(), 'OpenCodeException: Test error message');
      });

      test('toString includes status code in message when provided', () {
        final exception = OpenCodeException('Failed request (status: 404)');
        expect(exception.toString(), 'OpenCodeException: Failed request (status: 404)');
      });

      test('exception is thrown on API failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        expect(
          () => client.getGlobalConfig(),
          throwsA(isA<OpenCodeException>()),
        );
      });

      test('exception message contains status code', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        try {
          await client.getGlobalConfig();
          fail('Expected OpenCodeException');
        } on OpenCodeException catch (e) {
          expect(e.message, contains('404'));
        }
      });
    });

    group('healthCheck', () {
      test('returns healthy result on 200 with healthy true', () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"healthy": true, "version": "1.0.0"}', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, true);
        expect(result.version, '1.0.0');
        expect(result.error, isNull);
      });

      test('returns unhealthy result on non-200', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, 'Server returned 500');
      });

      test('catches exceptions and returns error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection refused');
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, contains('Connection refused'));
      });

      test('returns unhealthy when response is not valid JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json', 200);
        });

        platformHttpClient.setTestClient(mockClient);

        final client = OpenCodeClient();
        await client.initialize(config: ServerConfig(url: 'http://localhost:4096'));

        final result = await client.healthCheck();

        expect(result.healthy, false);
        expect(result.error, isNotNull);
      });
    });
  });

  group('HealthCheckResult', () {
    test('creates with healthy true', () {
      final result = HealthCheckResult(healthy: true);
      expect(result.healthy, true);
      expect(result.version, isNull);
      expect(result.error, isNull);
    });

    test('creates with healthy false and error', () {
      final result = HealthCheckResult(healthy: false, error: 'Server error');
      expect(result.healthy, false);
      expect(result.error, 'Server error');
    });

    test('creates with version info', () {
      final result = HealthCheckResult(healthy: true, version: '1.0.0');
      expect(result.version, '1.0.0');
    });

    test('handles all properties together', () {
      final result = HealthCheckResult(
        healthy: true,
        version: '2.0.0',
        error: null,
      );
      expect(result.healthy, true);
      expect(result.version, '2.0.0');
      expect(result.error, isNull);
    });
  });
}
