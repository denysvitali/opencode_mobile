import 'dart:convert';
import 'package:http/http.dart' as http;

import '../http/http_client.dart';
import '../models/config.dart';
import '../models/session.dart';
import '../models/message.dart';
import '../models/permission.dart';

class OpenCodeClient {
  static final OpenCodeClient _instance = OpenCodeClient._();
  factory OpenCodeClient() => _instance;
  OpenCodeClient._();

  ServerConfig _config = ServerConfig();

  ServerConfig get config => _config;

  Future<void> initialize({required ServerConfig config}) async {
    _config = config;
  }

  Future<void> updateConfig(ServerConfig config) async {
    _config = config;
  }

  void _ensureInitialized() {
    if (_config.url.isEmpty) {
      throw StateError('OpenCodeClient not initialized. Call initialize() first.');
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': 'OpenCodeMobile/1.0',
      'Accept': 'application/json',
    };
    if (_config.hasAuth) {
      final credentials = base64Encode(
        utf8.encode('${_config.username}:${_config.password}'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }
    return headers;
  }

  Uri _buildUri(String path, {Map<String, dynamic>? queryParams}) {
    final baseUri = Uri.parse(_config.url);
    return baseUri.replace(
      path: '${baseUri.path}$path'.replaceAll('//', '/'),
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  bool _isSuccess(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  Future<http.Response> _get(String path, {Map<String, dynamic>? queryParams}) async {
    _ensureInitialized();
    final uri = _buildUri(path, queryParams: queryParams);
    return platformHttpClient.client.get(uri, headers: _buildHeaders());
  }

  Future<http.Response> _post(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    _ensureInitialized();
    final uri = _buildUri(path, queryParams: queryParams);
    return platformHttpClient.client.post(
      uri,
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> _delete(String path, {Map<String, dynamic>? queryParams}) async {
    _ensureInitialized();
    final uri = _buildUri(path, queryParams: queryParams);
    return platformHttpClient.client.delete(uri, headers: _buildHeaders());
  }

  Future<HealthCheckResult> healthCheck() async {
    try {
      final response = await _get('/global/health');
      if (_isSuccess(response.statusCode)) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return HealthCheckResult(
          healthy: data['healthy'] as bool? ?? false,
          version: data['version'] as String?,
        );
      }
      return HealthCheckResult(healthy: false, error: 'Server returned ${response.statusCode}');
    } catch (e) {
      return HealthCheckResult(healthy: false, error: e.toString());
    }
  }

  Future<List<Session>> listSessions({String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null) {
      queryParams['directory'] = directory;
    }
    final response = await _get('/session', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((s) => Session.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to list sessions: ${response.statusCode}');
  }

  Future<Session> createSession({
    String? directory,
    String? title,
  }) async {
    final body = <String, dynamic>{};
    if (directory != null) body['directory'] = directory;
    if (title != null) body['title'] = title;
    
    final response = await _post('/session', body: body);
    if (_isSuccess(response.statusCode)) {
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to create session: ${response.statusCode}');
  }

  Future<Session> getSession(String sessionId, {String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null) queryParams['directory'] = directory;
    
    final response = await _get('/session/$sessionId', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get session: ${response.statusCode}');
  }

  Future<void> deleteSession(String sessionId, {String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null) queryParams['directory'] = directory;
    
    final response = await _delete('/session/$sessionId', queryParams: queryParams);
    if (!_isSuccess(response.statusCode)) {
      throw OpenCodeException('Failed to delete session: ${response.statusCode}');
    }
  }

  Future<List<Message>> getMessages(String sessionId, {String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null) queryParams['directory'] = directory;
    
    final response = await _get('/session/$sessionId/message', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get messages: ${response.statusCode}');
  }

  Future<Message> sendMessage(
    String sessionId, {
    required String text,
    String? directory,
  }) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final body = {
      'parts': [
        {'type': 'text', 'text': text}
      ]
    };
    
    final response = await _post('/session/$sessionId/message', queryParams: queryParams, body: body);
    if (_isSuccess(response.statusCode)) {
      return Message.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to send message: ${response.statusCode}');
  }

  Stream<Message> sendMessageStream(
    String sessionId, {
    required String text,
    String? directory,
  }) async* {
    _ensureInitialized();
    
    final queryParams = directory != null ? {'directory': directory} : null;
    final uri = _buildUri('/session/$sessionId/message', queryParams: queryParams);
    
    final client = platformHttpClient.client;
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders());
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({
      'parts': [
        {'type': 'text', 'text': text}
      ]
    });

    final response = await client.send(request);
    final stream = response.stream;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data.isNotEmpty) {
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              yield Message.fromJson(json);
            } catch (_) {}
          }
        }
      }
    }
  }

  Future<void> abortSession(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/session/$sessionId/abort', queryParams: queryParams);
    if (!_isSuccess(response.statusCode)) {
      throw OpenCodeException('Failed to abort session: ${response.statusCode}');
    }
  }

  Future<List<Permission>> getPermissions({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/permission', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((p) => Permission.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get permissions: ${response.statusCode}');
  }

  Future<void> replyPermission(
    String permissionId, {
    required PermissionReply reply,
    String? directory,
  }) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post(
      '/permission/$permissionId/reply',
      queryParams: queryParams,
      body: {'reply': reply.name},
    );
    if (!_isSuccess(response.statusCode)) {
      throw OpenCodeException('Failed to reply to permission: ${response.statusCode}');
    }
  }

  void dispose() {}
}

class HealthCheckResult {
  final bool healthy;
  final String? version;
  final String? error;

  HealthCheckResult({
    required this.healthy,
    this.version,
    this.error,
  });
}

enum PermissionReply { once, always, reject }

class OpenCodeException implements Exception {
  final String message;
  OpenCodeException(this.message);

  @override
  String toString() => 'OpenCodeException: $message';
}
