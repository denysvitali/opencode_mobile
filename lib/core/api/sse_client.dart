import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';

enum SSEConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class SSEEvent {
  final String? event;
  final String? id;
  final Map<String, dynamic>? data;

  SSEEvent({this.event, this.id, this.data});

  factory SSEEvent.parse(String raw) {
    String? event;
    String? id;
    Map<String, dynamic>? data;

    for (final line in raw.split('\n')) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('id:')) {
        id = line.substring(3).trim();
      } else if (line.startsWith('data:')) {
        final dataStr = line.substring(5).trim();
        if (dataStr.isNotEmpty) {
          try {
            data = jsonDecode(dataStr) as Map<String, dynamic>;
          } catch (_) {
            data = {'raw': dataStr};
          }
        }
      }
    }

    return SSEEvent(event: event, id: id, data: data);
  }
}

class SSEClient {
  static final SSEClient _instance = SSEClient._();
  factory SSEClient() => _instance;
  SSEClient._();

  WebSocketChannel? _channel;

  SSEConnectionStatus _status = SSEConnectionStatus.disconnected;
  String? _serverUrl;
  String? _username;
  String? _password;
  bool _userCaWarningShown = false;

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _statusController = StreamController<SSEConnectionStatus>.broadcast();
  final _eventController = StreamController<SSEEvent>.broadcast();
  final _messageUpdateController = StreamController<Message>.broadcast();

  Stream<SSEConnectionStatus> get statusStream => _statusController.stream;
  Stream<SSEEvent> get eventStream => _eventController.stream;
  Stream<Message> get messageUpdateStream => _messageUpdateController.stream;

  SSEConnectionStatus get status => _status;

  void connect({
    required String serverUrl,
    String? username,
    String? password,
  }) {
    if (_channel != null && _status == SSEConnectionStatus.connected) {
      return;
    }

    _serverUrl = serverUrl;
    _username = username;
    _password = password;
    _updateStatus(SSEConnectionStatus.connecting);
    _connect();
  }

  void _connect() {
    if (_serverUrl == null) return;

    if (!_userCaWarningShown) {
      if (kDebugMode) {
        print('WARNING: WebSocket uses system default SSL. '
            'User CA certificates may not be trusted. '
            'For full user CA support, consider using HTTPS with a publicly trusted certificate.');
      }
      _userCaWarningShown = true;
    }

    final wsProtocol = _serverUrl!.startsWith('https') ? 'wss' : 'ws';
    final baseUrl = _serverUrl!.replaceFirst(RegExp(r'^https?://'), '$wsProtocol://');
    final wsUrl = '$baseUrl/event';

    if (kDebugMode) {
      print('SSE: Connecting to $wsUrl');
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.ready.then((_) {
        _updateStatus(SSEConnectionStatus.connected);
        _reconnectAttempts = 0;
        _startPingTimer();
      }).catchError((error) {
        if (kDebugMode) {
          print('SSE: Connection error: $error');
        }
        _handleError(error);
      });

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          if (kDebugMode) {
            print('SSE: Stream error: $error');
          }
          _updateStatus(SSEConnectionStatus.error);
        },
        onDone: () {
          if (kDebugMode) {
            print('SSE: Connection closed');
          }
          if (_status == SSEConnectionStatus.connected) {
            _updateStatus(SSEConnectionStatus.disconnected);
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('SSE: Failed to connect: $e');
      }
      _handleError(e);
    }
  }

  void _handleMessage(dynamic message) {
    final raw = message as String;
    if (raw.isEmpty) return;

    if (kDebugMode) {
      print('SSE: Received: ${raw.substring(0, raw.length > 100 ? 100 : raw.length)}...');
    }

    final event = SSEEvent.parse(raw);
    _eventController.add(event);

    if (event.event == 'message.updated' && event.data != null) {
      try {
        final msg = Message.fromJson(event.data!);
        _messageUpdateController.add(msg);
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse message: $e');
        }
      }
    }

    if (event.event == 'message.part.updated' && event.data != null) {
      try {
        final msg = Message.fromJson(event.data!);
        _messageUpdateController.add(msg);
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse message part: $e');
        }
      }
    }
  }

  void _handleError(dynamic error) {
    _updateStatus(SSEConnectionStatus.error);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('SSE: Max reconnect attempts reached');
      }
      return;
    }

    final delay = Duration(seconds: 1 << _reconnectAttempts);
    _reconnectAttempts++;

    if (kDebugMode) {
      print('SSE: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _connect();
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_status == SSEConnectionStatus.connected && _channel != null) {
        _channel!.sink.add('');
      }
    });
  }

  void _updateStatus(SSEConnectionStatus status) {
    if (_status != status) {
      _status = status;
      _statusController.add(status);
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _updateStatus(SSEConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _eventController.close();
    _messageUpdateController.close();
  }
}
