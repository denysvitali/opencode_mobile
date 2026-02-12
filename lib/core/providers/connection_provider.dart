import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/opencode_client.dart';
import '../api/sse_client.dart';
import '../models/config.dart';
import '../services/storage_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class ConnectionState {
  final ConnectionStatus status;
  final ServerConfig config;
  final String? errorMessage;
  final String? serverVersion;

  ConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.config = const ServerConfig(),
    this.errorMessage,
    this.serverVersion,
  });

  ConnectionState copyWith({
    ConnectionStatus? status,
    ServerConfig? config,
    String? errorMessage,
    String? serverVersion,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      config: config ?? this.config,
      errorMessage: errorMessage,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  bool get isConnected => status == ConnectionStatus.connected;
  bool get hasError => status == ConnectionStatus.error;
}

class ConnectionNotifier extends Notifier<ConnectionState> {
  @override
  ConnectionState build() {
    return ConnectionState();
  }

  Future<void> loadConfig() async {
    final config = await StorageService().loadServerConfig();
    state = state.copyWith(config: config);
  }

  Future<bool> connect({ServerConfig? newConfig}) async {
    final config = newConfig ?? state.config;
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      config: config,
      errorMessage: null,
    );

    try {
      await OpenCodeClient().updateConfig(config);
      final health = await OpenCodeClient().healthCheck();

      if (health.healthy) {
        await StorageService().saveServerConfig(config);

        SSEClient().connect(
          serverUrl: config.url,
          username: config.username,
          password: config.password,
        );

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

  void disconnect() {
    SSEClient().disconnect();
    state = state.copyWith(
      status: ConnectionStatus.disconnected,
      serverVersion: null,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, ConnectionState>(
  ConnectionNotifier.new,
);

final sseStatusProvider = StreamProvider<SSEConnectionStatus>((ref) {
  return SSEClient().statusStream;
});
