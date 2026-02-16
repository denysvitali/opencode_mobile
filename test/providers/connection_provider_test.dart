import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/providers/connection_provider.dart';

void main() {
  group('ConnectionState', () {
    test('initial state has disconnected status', () {
      final state = ConnectionState();
      expect(state.status, ConnectionStatus.disconnected);
      expect(state.config, isNotNull);
      expect(state.errorMessage, isNull);
      expect(state.serverVersion, isNull);
    });

    test('isConnected returns true only when status is connected', () {
      final disconnected = ConnectionState(status: ConnectionStatus.disconnected);
      final connecting = ConnectionState(status: ConnectionStatus.connecting);
      final connected = ConnectionState(status: ConnectionStatus.connected);
      final error = ConnectionState(status: ConnectionStatus.error);

      expect(disconnected.isConnected, false);
      expect(connecting.isConnected, false);
      expect(connected.isConnected, true);
      expect(error.isConnected, false);
    });

    test('hasError returns true only when status is error', () {
      final disconnected = ConnectionState(status: ConnectionStatus.disconnected);
      final connecting = ConnectionState(status: ConnectionStatus.connecting);
      final connected = ConnectionState(status: ConnectionStatus.connected);
      final error = ConnectionState(status: ConnectionStatus.error);

      expect(disconnected.hasError, false);
      expect(connecting.hasError, false);
      expect(connected.hasError, false);
      expect(error.hasError, true);
    });

    test('copyWith preserves unchanged fields', () {
      final original = ConnectionState(
        status: ConnectionStatus.connected,
        config: ServerConfig(url: 'http://test:4096', username: 'user', password: 'pass'),
        errorMessage: 'old error',
        serverVersion: '1.0.0',
      );

      final updated = original.copyWith(status: ConnectionStatus.disconnected);

      expect(updated.status, ConnectionStatus.disconnected);
      expect(updated.config.url, 'http://test:4096');
      expect(updated.config.username, 'user');
      expect(updated.errorMessage, 'old error');
      expect(updated.serverVersion, '1.0.0');
    });

    test('copyWith allows updating all fields', () {
      final original = ConnectionState();
      final updated = original.copyWith(
        status: ConnectionStatus.connected,
        config: ServerConfig(url: 'http://new:4096'),
        errorMessage: 'new error',
        serverVersion: '2.0.0',
      );

      expect(updated.status, ConnectionStatus.connected);
      expect(updated.config.url, 'http://new:4096');
      expect(updated.errorMessage, 'new error');
      expect(updated.serverVersion, '2.0.0');
    });
  });

  group('ConnectionNotifier', () {
    group('initial state', () {
      test('is correct', () {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(connectionProvider);
        expect(state.status, ConnectionStatus.disconnected);
        expect(state.config, isNotNull);
        expect(state.errorMessage, isNull);
      });
    });

    group('loadConfig', () {
      test('loads saved config from storage', () async {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              savedConfig: ServerConfig(url: 'http://saved:4096', username: 'saveduser'),
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        await notifier.loadConfig();

        expect(notifier.state.config.url, 'http://saved:4096');
        expect(notifier.state.config.username, 'saveduser');
      });
    });

    group('connect', () {
      test('with new config updates state', () async {
        final newConfig = ServerConfig(url: 'http://newconfig:4096', username: 'newuser');

        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              healthCheckResult: HealthCheckResult(healthy: true, version: '1.0.0'),
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        final result = await notifier.connect(newConfig: newConfig);

        expect(result, true);
        expect(notifier.state.config.url, 'http://newconfig:4096');
      });

      test('sets status to connecting then connected on success', () async {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              healthCheckResult: HealthCheckResult(healthy: true, version: '1.0.0'),
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        await notifier.connect();

        expect(notifier.state.status, ConnectionStatus.connected);
        expect(notifier.state.serverVersion, '1.0.0');
      });

      test('sets error status on health check failure', () async {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              healthCheckResult: HealthCheckResult(healthy: false, error: 'Server unhealthy'),
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        final result = await notifier.connect();

        expect(result, false);
        expect(notifier.state.status, ConnectionStatus.error);
        expect(notifier.state.errorMessage, 'Server unhealthy');
      });

      test('sets error status on health check exception', () async {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              shouldThrowError: true,
              errorMessage: 'Connection refused',
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        final result = await notifier.connect();

        expect(result, false);
        expect(notifier.state.status, ConnectionStatus.error);
        expect(notifier.state.errorMessage, contains('Connection refused'));
      });
    });

    group('disconnect', () {
      test('resets status to disconnected', () {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              initialStatus: ConnectionStatus.connected,
              initialVersion: '1.0.0',
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        notifier.disconnect();

        expect(notifier.state.status, ConnectionStatus.disconnected);
      });
    });

    group('clearError', () {
      test('resets status to disconnected', () {
        final container = ProviderContainer(
          overrides: [
            connectionProvider.overrideWith(() => TestConnectionNotifier(
              initialStatus: ConnectionStatus.error,
              initialError: 'Some error',
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionProvider.notifier);
        notifier.clearError();

        expect(notifier.state.status, ConnectionStatus.disconnected);
      });
    });
  });
}

class TestConnectionNotifier extends ConnectionNotifier {
  final ServerConfig? savedConfig;
  final HealthCheckResult? healthCheckResult;
  final bool shouldThrowError;
  final String? errorMessage;
  final ConnectionStatus? initialStatus;
  final String? initialVersion;
  final String? initialError;

  TestConnectionNotifier({
    this.savedConfig,
    this.healthCheckResult,
    this.shouldThrowError = false,
    this.errorMessage,
    this.initialStatus,
    this.initialVersion,
    this.initialError,
  });

  @override
  ConnectionState build() {
    return ConnectionState(
      status: initialStatus ?? ConnectionStatus.disconnected,
      config: savedConfig ?? ServerConfig(),
      serverVersion: initialVersion,
      errorMessage: initialError,
    );
  }

  @override
  Future<void> loadConfig() async {
    if (savedConfig != null) {
      state = state.copyWith(config: savedConfig);
    }
  }

  @override
  Future<bool> connect({ServerConfig? newConfig}) async {
    final config = newConfig ?? state.config;
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      config: config,
      errorMessage: null,
    );

    try {
      if (shouldThrowError) {
        throw Exception(errorMessage ?? 'Connection error');
      }

      final health = healthCheckResult ?? HealthCheckResult(healthy: true);

      if (health.healthy) {
        state = state.copyWith(
          status: ConnectionStatus.connected,
          serverVersion: health.version,
        );
        return true;
      } else {
        state = state.copyWith(
          status: ConnectionStatus.error,
          errorMessage: health.error ?? 'Server health check failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  @override
  void disconnect() {
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      serverVersion: null,
    );
  }

  @override
  void clearError() {
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      errorMessage: null,
    );
  }
}
