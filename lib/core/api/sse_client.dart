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
              if (parsed.containsKey('payload') && parsed['payload'] is Map) {
                final payload = parsed['payload'] as Map<String, dynamic>;
                if (payload.containsKey('type')) {
                  event = payload['type'] as String?;
                }
                if (payload.containsKey('properties')) {
                  data = payload['properties'] as Map<String, dynamic>;
                } else {
                  data = payload;
                }
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

class _SSEConnection {
  final String url;
  final String? directory;
  http.StreamedResponse? response;
  StreamSubscription<List<int>>? subscription;

  _SSEConnection({required this.url, this.directory});
}

class SSEClient {
  static final SSEClient _instance = SSEClient._();
  factory SSEClient() => _instance;
  SSEClient._();

  _SSEConnection? _globalConnection;
  final Map<String, _SSEConnection> _projectConnections = {};

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
  final _messagePartUpdateController = StreamController<Message>.broadcast();
  final _sessionUpdateController = StreamController<Session>.broadcast();
  final _sessionStatusController = StreamController<Map<String, String>>.broadcast();
  final _sessionCreatedController = StreamController<Session>.broadcast();
  final _sessionDeletedController = StreamController<String>.broadcast();
  final _permissionController = StreamController<Permission>.broadcast();
  final _fileEditedController = StreamController<Map<String, dynamic>>.broadcast();
  final _installationUpdateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SSEConnectionStatus> get statusStream => _statusController.stream;
  Stream<SSEEvent> get eventStream => _eventController.stream;
  Stream<Message> get messageUpdateStream => _messageUpdateController.stream;
  Stream<Message> get messagePartUpdateStream => _messagePartUpdateController.stream;
  Stream<Session> get sessionUpdateStream => _sessionUpdateController.stream;
  Stream<Map<String, String>> get sessionStatusStream => _sessionStatusController.stream;
  Stream<Session> get sessionCreatedStream => _sessionCreatedController.stream;
  Stream<String> get sessionDeletedStream => _sessionDeletedController.stream;
  Stream<Permission> get permissionStream => _permissionController.stream;
  Stream<Map<String, dynamic>> get fileEditedStream => _fileEditedController.stream;
  Stream<Map<String, dynamic>> get installationUpdateStream => _installationUpdateController.stream;

  SSEConnectionStatus get status => _status;

  void connect({
    required String serverUrl,
    String? username,
    String? password,
    String? directory,
  }) {
    _serverUrl = serverUrl;
    _username = username;
    _password = password;

    if (!_userCaWarningShown) {
      if (kDebugMode) {
        print('SSE: Using HTTP streaming for SSE connection');
      }
      _userCaWarningShown = true;
    }

    _updateStatus(SSEConnectionStatus.connecting);
    _connectGlobal();

    if (directory != null) {
      connectProject(directory);
    }
  }

  Future<void> _connectGlobal() async {
    if (_serverUrl == null) return;

    final sseUrl = '$_serverUrl/global/event';

    if (kDebugMode) {
      print('SSE: Connecting to global events at $sseUrl');
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

      _globalConnection = _SSEConnection(url: sseUrl);
      _globalConnection!.response = response;
      _updateStatus(SSEConnectionStatus.connected);
      _reconnectAttempts = 0;

      String buffer = '';
      _globalConnection!.subscription = response.stream.listen(
        (chunk) {
          buffer += utf8.decode(chunk);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              _handleData(line.substring(6), isGlobal: true);
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
            print('SSE: Global connection closed');
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

  Future<void> connectProject(String directory) async {
    if (_serverUrl == null || _projectConnections.containsKey(directory)) return;

    final sseUrl = '$_serverUrl/event?directory=${Uri.encodeComponent(directory)}';

    if (kDebugMode) {
      print('SSE: Connecting to project events at $sseUrl');
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
          print('SSE: Project HTTP error: ${response.statusCode}');
        }
        return;
      }

      final connection = _SSEConnection(url: sseUrl, directory: directory);
      connection.response = response;
      _projectConnections[directory] = connection;

      String buffer = '';
      connection.subscription = response.stream.listen(
        (chunk) {
          buffer += utf8.decode(chunk);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            if (line.startsWith('data: ')) {
              _handleData(line.substring(6), directory: directory);
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('SSE: Project stream error: $error');
          }
          _projectConnections.remove(directory);
        },
        onDone: () {
          if (kDebugMode) {
            print('SSE: Project connection closed');
          }
          _projectConnections.remove(directory);
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('SSE: Failed to connect project: $e');
      }
    }
  }

  void disconnectProject(String directory) {
    final connection = _projectConnections[directory];
    if (connection != null) {
      connection.subscription?.cancel();
      _projectConnections.remove(directory);
    }
  }

  void _handleData(String dataStr, {String? directory, bool isGlobal = false}) {
    if (dataStr.isEmpty) return;

    if (kDebugMode) {
      print('SSE: Received: ${dataStr.substring(0, dataStr.length > 100 ? 100 : dataStr.length)}...');
    }

    final event = SSEEvent.parse('data: $dataStr');
    _eventController.add(event);

    if (isGlobal) {
      _handleGlobalEvent(event);
    } else {
      _handleProjectEvent(event, directory);
    }
  }

  void _handleGlobalEvent(SSEEvent event) {
    switch (event.event) {
      case 'installation.updated':
      case 'installation.update-available':
        if (event.data != null) {
          _installationUpdateController.add(event.data!);
        }
        break;
      case 'server.instance.disposed':
      case 'global.disposed':
        if (kDebugMode) {
          print('SSE: Server disposing');
        }
        break;
    }
  }

  void _handleProjectEvent(SSEEvent event, String? directory) {
    final payload = event.data;
    if (payload == null) return;

    Map<String, dynamic>? extractInfo(Map<String, dynamic> data) {
      if (data.containsKey('payload') && data['payload'] is Map) {
        final inner = data['payload'] as Map<String, dynamic>;
        if (inner.containsKey('properties') && inner['properties'] is Map) {
          return inner['properties'] as Map<String, dynamic>;
        }
      }
      return data;
    }

    try {
      switch (event.event) {
        case 'message.updated':
          final info = extractInfo(payload);
          if (info?.containsKey('info') == true) {
            final msg = Message.fromJson(info!['info'] as Map<String, dynamic>);
            _messageUpdateController.add(msg);
          }
          break;

        case 'message.part.updated':
          final info = extractInfo(payload);
          if (info?.containsKey('info') == true) {
            final msg = Message.fromJson(info!['info'] as Map<String, dynamic>);
            _messagePartUpdateController.add(msg);
          }
          break;

        case 'message.part.removed':
          if (kDebugMode) {
            print('SSE: Message part removed');
          }
          break;

        case 'session.updated':
          final info = extractInfo(payload);
          if (info?.containsKey('info') == true) {
            final session = Session.fromJson(info!['info'] as Map<String, dynamic>);
            _sessionUpdateController.add(session);
          }
          break;

        case 'session.status':
          final info = extractInfo(payload);
          if (info != null) {
            _sessionStatusController.add(Map<String, String>.from(info));
          }
          break;

        case 'session.created':
          final info = extractInfo(payload);
          if (info?.containsKey('info') == true) {
            final session = Session.fromJson(info!['info'] as Map<String, dynamic>);
            _sessionCreatedController.add(session);
          }
          break;

        case 'session.deleted':
          final info = extractInfo(payload);
          final sessionId = info?['id'] as String?;
          if (sessionId != null) {
            _sessionDeletedController.add(sessionId);
          }
          break;

        case 'permission.asked':
        case 'permission.created':
          final info = extractInfo(payload);
          if (info?.containsKey('info') == true) {
            final permission = Permission.fromJson(info!['info'] as Map<String, dynamic>);
            _permissionController.add(permission);
          }
          break;

        case 'question.asked':
          if (kDebugMode) {
            print('SSE: Question asked');
          }
          break;

        case 'file.edited':
          final info = extractInfo(payload);
          if (info != null) {
            _fileEditedController.add(info);
          }
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('SSE: Failed to parse event ${event.event}: $e');
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
      _connectGlobal();
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

    _globalConnection?.subscription?.cancel();
    _globalConnection = null;

    for (final connection in _projectConnections.values) {
      connection.subscription?.cancel();
    }
    _projectConnections.clear();

    _updateStatus(SSEConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _eventController.close();
    _messageUpdateController.close();
    _messagePartUpdateController.close();
    _sessionUpdateController.close();
    _sessionStatusController.close();
    _sessionCreatedController.close();
    _sessionDeletedController.close();
    _permissionController.close();
    _fileEditedController.close();
    _installationUpdateController.close();
  }
}
