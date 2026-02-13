import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../http/http_client.dart';
import '../models/message.dart';
import '../models/permission.dart';
import '../models/session.dart';

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
            final parsed = jsonDecode(dataStr);
            if (parsed is Map<String, dynamic>) {
              // Check for server's payload format: {"payload":{"type":"...","properties":{}}}
              if (parsed.containsKey('payload') && parsed['payload'] is Map) {
                final payload = parsed['payload'] as Map<String, dynamic>;
                // Extract event type from payload.type
                if (payload.containsKey('type')) {
                  event = payload['type'] as String?;
                }
                // Extract properties as data
                if (payload.containsKey('properties')) {
                  data = payload['properties'] as Map<String, dynamic>;
                } else {
                  data = payload;
                }
                // Also keep the full payload for reference
                data = parsed;
              } else {
                data = parsed;
              }
            }
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

  http.StreamedResponse? _response;
  StreamSubscription<List<int>>? _subscription;

  SSEConnectionStatus _status = SSEConnectionStatus.disconnected;
  String? _serverUrl;
  String? _username;
  String? _password;
  bool _userCaWarningShown = false;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _statusController = StreamController<SSEConnectionStatus>.broadcast();
  final _eventController = StreamController<SSEEvent>.broadcast();
  final _messageUpdateController = StreamController<Message>.broadcast();
  final _sessionUpdateController = StreamController<Session>.broadcast();
  final _sessionCreatedController = StreamController<Session>.broadcast();
  final _sessionDeletedController = StreamController<String>.broadcast();
  final _permissionController = StreamController<Permission>.broadcast();

  Stream<SSEConnectionStatus> get statusStream => _statusController.stream;
  Stream<SSEEvent> get eventStream => _eventController.stream;
  Stream<Message> get messageUpdateStream => _messageUpdateController.stream;
  Stream<Session> get sessionUpdateStream => _sessionUpdateController.stream;
  Stream<Session> get sessionCreatedStream => _sessionCreatedController.stream;
  Stream<String> get sessionDeletedStream => _sessionDeletedController.stream;
  Stream<Permission> get permissionStream => _permissionController.stream;

  SSEConnectionStatus get status => _status;

  void connect({
    required String serverUrl,
    String? username,
    String? password,
  }) {
    if (_response != null && _status == SSEConnectionStatus.connected) {
      return;
    }

    _serverUrl = serverUrl;
    _username = username;
    _password = password;
    _updateStatus(SSEConnectionStatus.connecting);
    _connect();
  }

  Future<void> _connect() async {
    if (_serverUrl == null) return;

    if (!_userCaWarningShown) {
      if (kDebugMode) {
        print('SSE: Using HTTP streaming for SSE connection');
      }
      _userCaWarningShown = true;
    }

    final sseUrl = '$_serverUrl/global/event';

    if (kDebugMode) {
      print('SSE: Connecting to $sseUrl');
    }

    try {
      final uri = Uri.parse(sseUrl);
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      if (_username != null && _password != null) {
        final credentials = base64Encode(utf8.encode('$_username:$_password'));
        request.headers['Authorization'] = 'Basic $credentials';
      }

      final client = platformHttpClient.client;
      final response = await client.send(request);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('SSE: HTTP error: ${response.statusCode}');
        }
        _handleError(Exception('HTTP ${response.statusCode}'));
        return;
      }

      _response = response;
      _updateStatus(SSEConnectionStatus.connected);
      _reconnectAttempts = 0;

      String buffer = '';
      _subscription = response.stream.listen(
        (chunk) {
          buffer += utf8.decode(chunk);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              _handleData(line.substring(6));
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('SSE: Stream error: $error');
          }
          _updateStatus(SSEConnectionStatus.error);
          _scheduleReconnect();
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

  void _handleData(String dataStr) {
    if (dataStr.isEmpty) return;

    if (kDebugMode) {
      print('SSE: Received: ${dataStr.substring(0, dataStr.length > 100 ? 100 : dataStr.length)}...');
    }

    final event = SSEEvent.parse('data: $dataStr');
    _eventController.add(event);

    // Handle message.updated
    if (event.event == 'message.updated' && event.data != null) {
      try {
        // The data contains the full payload, need to extract info
        final payload = event.data!;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          final innerPayload = payload['payload'] as Map<String, dynamic>;
          if (innerPayload.containsKey('properties') && innerPayload['properties'] is Map) {
            final properties = innerPayload['properties'] as Map<String, dynamic>;
            if (properties.containsKey('info')) {
              final msg = Message.fromJson(properties['info'] as Map<String, dynamic>);
              _messageUpdateController.add(msg);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse message.updated: $e');
        }
      }
    }

    // Handle message.part.updated
    if (event.event == 'message.part.updated' && event.data != null) {
      try {
        final payload = event.data!;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          final innerPayload = payload['payload'] as Map<String, dynamic>;
          if (innerPayload.containsKey('properties') && innerPayload['properties'] is Map) {
            final properties = innerPayload['properties'] as Map<String, dynamic>;
            if (properties.containsKey('info')) {
              final msg = Message.fromJson(properties['info'] as Map<String, dynamic>);
              _messageUpdateController.add(msg);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse message.part.updated: $e');
        }
      }
    }

    // Handle session.updated
    if (event.event == 'session.updated' && event.data != null) {
      try {
        final payload = event.data!;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          final innerPayload = payload['payload'] as Map<String, dynamic>;
          if (innerPayload.containsKey('properties') && innerPayload['properties'] is Map) {
            final properties = innerPayload['properties'] as Map<String, dynamic>;
            if (properties.containsKey('info')) {
              final session = Session.fromJson(properties['info'] as Map<String, dynamic>);
              _sessionUpdateController.add(session);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse session.updated: $e');
        }
      }
    }

    // Handle session.created
    if (event.event == 'session.created' && event.data != null) {
      try {
        final payload = event.data!;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          final innerPayload = payload['payload'] as Map<String, dynamic>;
          if (innerPayload.containsKey('properties') && innerPayload['properties'] is Map) {
            final properties = innerPayload['properties'] as Map<String, dynamic>;
            if (properties.containsKey('info')) {
              final session = Session.fromJson(properties['info'] as Map<String, dynamic>);
              _sessionCreatedController.add(session);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse session.created: $e');
        }
      }
    }

    // Handle session.deleted
    if (event.event == 'session.deleted' && event.data != null) {
      try {
        final payload = event.data!;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          final innerPayload = payload['payload'] as Map<String, dynamic>;
          if (innerPayload.containsKey('properties') && innerPayload['properties'] is Map) {
            final properties = innerPayload['properties'] as Map<String, dynamic>;
            final sessionId = properties['id'] as String?;
            if (sessionId != null) {
              _sessionDeletedController.add(sessionId);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse session.deleted: $e');
        }
      }
    }

    // Handle permission.created
    if (event.event == 'permission.created' && event.data != null) {
      try {
        final payload = event.data!;
        if (payload.containsKey('payload') && payload['payload'] is Map) {
          final innerPayload = payload['payload'] as Map<String, dynamic>;
          if (innerPayload.containsKey('properties') && innerPayload['properties'] is Map) {
            final properties = innerPayload['properties'] as Map<String, dynamic>;
            if (properties.containsKey('info')) {
              final permission = Permission.fromJson(properties['info'] as Map<String, dynamic>);
              _permissionController.add(permission);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SSE: Failed to parse permission.created: $e');
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

  void _updateStatus(SSEConnectionStatus status) {
    if (_status != status) {
      _status = status;
      _statusController.add(status);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _response = null;
    _updateStatus(SSEConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _eventController.close();
    _messageUpdateController.close();
    _sessionUpdateController.close();
    _sessionCreatedController.close();
    _sessionDeletedController.close();
    _permissionController.close();
  }
}
