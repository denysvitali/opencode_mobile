import 'dart:convert';
import 'package:http/http.dart' as http;

import '../http/http_client.dart';
import '../models/config.dart';
import '../models/project.dart';
import '../models/session.dart';
import '../models/message.dart';
import '../models/permission.dart';
import '../models/provider.dart';

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

  Future<List<Project>> listProjects() async {
    final response = await _get('/project');
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((p) => Project.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to list projects: ${response.statusCode}');
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
      return data.map((item) {
        final m = item as Map<String, dynamic>;
        // Handle {info: Message, parts: Part[]} wrapper format
        if (m.containsKey('info') && m.containsKey('parts')) {
          final info = m['info'] as Map<String, dynamic>;
          final parts = m['parts'] as List<dynamic>? ?? [];
          info['parts'] = parts;
          return Message.fromJson(info);
        }
        return Message.fromJson(m);
      }).toList();
    }
    throw OpenCodeException('Failed to get messages: ${response.statusCode}');
  }

  Future<Message> sendMessage(
    String sessionId, {
    required String text,
    String? directory,
    String? providerID,
    String? modelID,
  }) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final body = <String, dynamic>{
      'parts': [
        {'type': 'text', 'text': text}
      ],
    };
    if (providerID != null && modelID != null) {
      body['model'] = {'providerID': providerID, 'modelID': modelID};
    }

    final response = await _post('/session/$sessionId/message', queryParams: queryParams, body: body);
    if (_isSuccess(response.statusCode)) {
      // Server may return empty body when using explicit model selection
      if (response.body.isEmpty) {
        return Message(
          id: '',
          sessionId: sessionId,
          role: MessageRole.user,
          parts: [],
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Ensure sessionId is set (server may not include it since it's in the URL)
      json['sessionID'] = sessionId;
      return Message.fromJson(json);
    }
    throw OpenCodeException('Failed to send message: ${response.statusCode}');
  }

  Stream<Message> sendMessageStream(
    String sessionId, {
    required String text,
    String? directory,
    String? providerID,
    String? modelID,
  }) async* {
    _ensureInitialized();

    final queryParams = directory != null ? {'directory': directory} : null;
    final uri = _buildUri('/session/$sessionId/message', queryParams: queryParams);

    final client = platformHttpClient.client;
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders());
    request.headers['Accept'] = 'text/event-stream';
    final body = <String, dynamic>{
      'parts': [
        {'type': 'text', 'text': text}
      ],
    };
    if (providerID != null && modelID != null) {
      body['model'] = {'providerID': providerID, 'modelID': modelID};
    }
    request.body = jsonEncode(body);

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

  Future<List<Provider>> getProviders() async {
    final response = await _get('/provider');
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final all = data['all'] as List<dynamic>? ?? [];
      return all.map((p) => Provider.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get providers: ${response.statusCode}');
  }

  Future<List<Provider>> getConfigProviders() async {
    final response = await _get('/config/providers');
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final providers = data['providers'] as List<dynamic>? ?? [];
      return providers.map((p) => Provider.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get config providers: ${response.statusCode}');
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
