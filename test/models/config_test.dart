import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/config.dart';

void main() {
  group('ServerConfig', () {
    test('creates with default values', () {
      final config = ServerConfig();
      expect(config.url, 'http://localhost:4096');
      expect(config.isConnected, false);
      expect(config.hasAuth, false);
    });

    test('fromJson parses correctly', () {
      final json = {
        'url': 'http://192.168.1.1:4096',
        'username': 'user',
        'password': 'pass',
        'isConnected': true,
        'version': '1.0.0',
      };
      final config = ServerConfig.fromJson(json);
      expect(config.url, 'http://192.168.1.1:4096');
      expect(config.username, 'user');
      expect(config.password, 'pass');
      expect(config.isConnected, true);
      expect(config.version, '1.0.0');
    });

    test('fromJson uses defaults for missing values', () {
      final config = ServerConfig.fromJson({});
      expect(config.url, 'http://localhost:4096');
      expect(config.isConnected, false);
    });

    test('hasAuth returns true when username exists', () {
      expect(ServerConfig(username: 'user').hasAuth, true);
      expect(ServerConfig().hasAuth, false);
      expect(ServerConfig(username: '').hasAuth, false);
    });

    test('copyWith creates new instance', () {
      final config = ServerConfig(url: 'http://old:4096');
      final updated = config.copyWith(url: 'http://new:4096', isConnected: true);
      expect(updated.url, 'http://new:4096');
      expect(updated.isConnected, true);
    });

    test('toJson produces correct output', () {
      final config = ServerConfig(
        url: 'http://test:4096',
        username: 'user',
        isConnected: true,
      );
      final json = config.toJson();
      expect(json['url'], 'http://test:4096');
      expect(json['username'], 'user');
      expect(json['isConnected'], true);
    });
  });

  group('AppConfig', () {
    test('creates with default values', () {
      final config = AppConfig();
      expect(config.theme, isNull);
      expect(config.agent, isNull);
    });

    test('fromJson parses correctly', () {
      final json = {
        'theme': 'dark',
        'agent': {'model': 'claude-3', 'provider': 'anthropic'},
        'provider': {'type': 'openai'},
      };
      final config = AppConfig.fromJson(json);
      expect(config.theme, 'dark');
      expect(config.agent, isNotNull);
      expect(config.agent!.model, 'claude-3');
      expect(config.agent!.provider, 'anthropic');
      expect(config.provider, isNotNull);
    });

    test('toJson produces correct output', () {
      final config = AppConfig(
        theme: 'light',
        agent: AppConfigAgent(model: 'gpt-4', provider: 'openai'),
      );
      final json = config.toJson();
      expect(json['theme'], 'light');
      expect(json['agent']['model'], 'gpt-4');
    });

    test('copyWith creates new instance', () {
      final config = AppConfig(theme: 'dark');
      final updated = config.copyWith(theme: 'light');
      expect(updated.theme, 'light');
    });
  });

  group('AppConfigAgent', () {
    test('fromJson parses correctly', () {
      final json = {'model': 'claude-3', 'provider': 'anthropic'};
      final agent = AppConfigAgent.fromJson(json);
      expect(agent.model, 'claude-3');
      expect(agent.provider, 'anthropic');
    });

    test('toJson omits null values', () {
      final agent = AppConfigAgent(model: 'gpt-4');
      final json = agent.toJson();
      expect(json.containsKey('model'), true);
      expect(json.containsKey('provider'), false);
    });
  });
}
