import 'dart:convert';
import 'package:http/http.dart' as http;

import '../http/http_client.dart';
import '../models/config.dart';
import '../models/project.dart';
import '../models/session.dart';
import '../models/message.dart';
import '../models/permission.dart';
import '../models/provider.dart';
import '../models/pty.dart';
import '../models/todo.dart';
import '../models/diff.dart';
import '../models/worktree.dart';
import '../models/tool.dart';
import '../models/mcp_resource.dart';

class OpenCodeClient {
  static final OpenCodeClient _instance = OpenCodeClient._();
  factory OpenCodeClient() => _instance;
  OpenCodeClient._();

  ServerConfig _config = ServerConfig();

  ServerConfig get config => _config;

  Future<void> initialize({required ServerConfig config}) async {
    _config = config;
  }

  Future<void> setServerConfig(ServerConfig config) async {
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

  Future<http.Response> _patch(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    _ensureInitialized();
    final uri = _buildUri(path, queryParams: queryParams);
    return platformHttpClient.client.patch(
      uri,
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> _put(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    _ensureInitialized();
    final uri = _buildUri(path, queryParams: queryParams);
    return platformHttpClient.client.put(
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

  // ==================== Global Routes ====================

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

  Future<AppConfig> getGlobalConfig() async {
    final response = await _get('/global/config');
    if (_isSuccess(response.statusCode)) {
      return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get global config: ${response.statusCode}');
  }

  Future<AppConfig> updateGlobalConfig(AppConfig config) async {
    final response = await _patch('/global/config', body: config.toJson());
    if (_isSuccess(response.statusCode)) {
      return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to update global config: ${response.statusCode}');
  }

  Future<bool> disposeGlobal() async {
    final response = await _post('/global/dispose');
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to dispose global: ${response.statusCode}');
  }

  // ==================== Project Routes ====================

  Future<List<Project>> listProjects({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/project', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((p) => Project.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to list projects: ${response.statusCode}');
  }

  Future<Project> getCurrentProject({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/project/current', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return Project.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get current project: ${response.statusCode}');
  }

  Future<Project> updateProject(String projectId, ProjectUpdateInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _patch('/project/$projectId', queryParams: queryParams, body: input.toJson());
    if (_isSuccess(response.statusCode)) {
      return Project.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to update project: ${response.statusCode}');
  }

  // ==================== Config Routes ====================

  Future<AppConfig> getConfig({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/config', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get config: ${response.statusCode}');
  }

  Future<AppConfig> updateConfig(AppConfig config, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _patch('/config', queryParams: queryParams, body: config.toJson());
    if (_isSuccess(response.statusCode)) {
      return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to update config: ${response.statusCode}');
  }

  Future<ProvidersResponse> getConfigProviders({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/config/providers', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return ProvidersResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get config providers: ${response.statusCode}');
  }

  // ==================== Session Routes ====================

  Future<List<Session>> listSessions({
    String? directory,
    bool? roots,
    int? start,
    String? search,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{};
    if (directory != null) queryParams['directory'] = directory;
    if (roots == true) queryParams['roots'] = 'true';
    if (start != null) queryParams['start'] = start;
    if (search != null) queryParams['search'] = search;
    if (limit != null) queryParams['limit'] = limit;
    
    final response = await _get('/session', queryParams: queryParams.isNotEmpty ? queryParams : null);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((s) => Session.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to list sessions: ${response.statusCode}');
  }

  Future<Session> createSession({
    String? directory,
    SessionCreateInput? input,
  }) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/session', queryParams: queryParams, body: input?.toJson() ?? {});
    if (_isSuccess(response.statusCode)) {
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to create session: ${response.statusCode}');
  }

  Future<Map<String, String>> getSessionStatuses({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/status', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v.toString()));
    }
    throw OpenCodeException('Failed to get session statuses: ${response.statusCode}');
  }

  Future<Session> getSession(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/$sessionId', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get session: ${response.statusCode}');
  }

  Future<Session> updateSession(String sessionId, SessionUpdateInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _patch('/session/$sessionId', queryParams: queryParams, body: input.toJson());
    if (_isSuccess(response.statusCode)) {
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to update session: ${response.statusCode}');
  }

  Future<bool> deleteSession(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _delete('/session/$sessionId', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to delete session: ${response.statusCode}');
  }

  Future<List<Session>> getSessionChildren(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/$sessionId/children', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((s) => Session.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get session children: ${response.statusCode}');
  }

  Future<List<Todo>> getSessionTodos(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/$sessionId/todo', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((t) => Todo.fromJson(t as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get session todos: ${response.statusCode}');
  }

  Future<bool> initSession(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/session/$sessionId/init', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to init session: ${response.statusCode}');
  }

  Future<SessionDiff> getSessionDiff(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/$sessionId/diff', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return SessionDiff.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get session diff: ${response.statusCode}');
  }

  Future<Session> revertToMessage(String sessionId, String messageId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/$sessionId/revert/$messageId', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to revert to message: ${response.statusCode}');
  }

  // ==================== Message Routes ====================

  Future<List<Message>> getMessages(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/session/$sessionId/message', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((item) {
        final m = item as Map<String, dynamic>;
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

  Future<Message> sendPrompt(
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
      if (response.body.isEmpty) {
        throw OpenCodeException('Empty response from server');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      json['sessionID'] = sessionId;
      return Message.fromJson(json);
    }
    throw OpenCodeException('Failed to send prompt: ${response.statusCode}');
  }

  Stream<Message> sendPromptStream(
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

  Future<bool> cancelSession(String sessionId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/session/$sessionId/cancel', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to cancel session: ${response.statusCode}');
  }

  // Legacy alias
  Future<bool> abortSession(String sessionId, {String? directory}) async {
    return cancelSession(sessionId, directory: directory);
  }

  // ==================== Permission Routes ====================

  Future<List<Permission>> getPermissions({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/permission', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((p) => Permission.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get permissions: ${response.statusCode}');
  }

  Future<bool> replyPermission(
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
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to reply to permission: ${response.statusCode}');
  }

  // ==================== Auth Routes ====================

  Future<bool> setAuth(String providerId, Map<String, dynamic> credentials) async {
    final response = await _put('/auth/$providerId', body: credentials);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to set auth: ${response.statusCode}');
  }

  Future<bool> removeAuth(String providerId) async {
    final response = await _delete('/auth/$providerId');
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to remove auth: ${response.statusCode}');
  }

  // ==================== PTY Routes ====================

  Future<List<Pty>> listPtys({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/pty', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((p) => Pty.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to list ptys: ${response.statusCode}');
  }

  Future<Pty> createPty(PtyCreateInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/pty', queryParams: queryParams, body: input.toJson());
    if (_isSuccess(response.statusCode)) {
      return Pty.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to create pty: ${response.statusCode}');
  }

  Future<Pty> getPty(String ptyId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/pty/$ptyId', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return Pty.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get pty: ${response.statusCode}');
  }

  Future<Pty> updatePty(String ptyId, PtyUpdateInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _put('/pty/$ptyId', queryParams: queryParams, body: input.toJson());
    if (_isSuccess(response.statusCode)) {
      return Pty.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to update pty: ${response.statusCode}');
  }

  Future<bool> removePty(String ptyId, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _delete('/pty/$ptyId', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to remove pty: ${response.statusCode}');
  }

  // ==================== Instance Routes ====================

  Future<bool> disposeInstance({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/instance/dispose', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to dispose instance: ${response.statusCode}');
  }

  // ==================== Tool Routes (Experimental) ====================

  Future<List<String>> getToolIds({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/experimental/tool/ids', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final ids = data['ids'] as List<dynamic>? ?? [];
      return ids.map((e) => e.toString()).toList();
    }
    throw OpenCodeException('Failed to get tool ids: ${response.statusCode}');
  }

  Future<ToolList> getTools({
    required String provider,
    required String model,
    String? directory,
  }) async {
    final queryParams = <String, dynamic>{
      'provider': provider,
      'model': model,
    };
    if (directory != null) queryParams['directory'] = directory;
    final response = await _get('/experimental/tool', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return ToolList.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get tools: ${response.statusCode}');
  }

  // ==================== Worktree Routes (Experimental) ====================

  Future<Worktree> createWorktree(WorktreeCreateInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/experimental/worktree', queryParams: queryParams, body: input.toJson());
    if (_isSuccess(response.statusCode)) {
      return Worktree.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to create worktree: ${response.statusCode}');
  }

  Future<List<String>> listWorktrees({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/experimental/worktree', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => e.toString()).toList();
    }
    throw OpenCodeException('Failed to list worktrees: ${response.statusCode}');
  }

  Future<bool> removeWorktree(WorktreeRemoveInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _delete('/experimental/worktree', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to remove worktree: ${response.statusCode}');
  }

  Future<bool> resetWorktree(WorktreeResetInput input, {String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _post('/experimental/worktree/reset', queryParams: queryParams, body: input.toJson());
    if (_isSuccess(response.statusCode)) {
      return jsonDecode(response.body) as bool? ?? true;
    }
    throw OpenCodeException('Failed to reset worktree: ${response.statusCode}');
  }

  // ==================== MCP Resource Routes (Experimental) ====================

  Future<Map<String, McpResource>> getMcpResources({String? directory}) async {
    final queryParams = directory != null ? {'directory': directory} : null;
    final response = await _get('/experimental/resource', queryParams: queryParams);
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, McpResource.fromJson(v as Map<String, dynamic>)));
    }
    throw OpenCodeException('Failed to get mcp resources: ${response.statusCode}');
  }

  // ==================== Legacy/Deprecated ====================

  @Deprecated('Use sendPrompt instead')
  Future<Message> sendMessage(
    String sessionId, {
    required String text,
    String? directory,
    String? providerID,
    String? modelID,
  }) async {
    return sendPrompt(sessionId, text: text, directory: directory, providerID: providerID, modelID: modelID);
  }

  @Deprecated('Use sendPromptStream instead')
  Stream<Message> sendMessageStream(
    String sessionId, {
    required String text,
    String? directory,
    String? providerID,
    String? modelID,
  }) async* {
    yield* sendPromptStream(sessionId, text: text, directory: directory, providerID: providerID, modelID: modelID);
  }

  @Deprecated('Use getConfigProviders instead')
  Future<List<Provider>> getProviders() async {
    final response = await _get('/provider');
    if (_isSuccess(response.statusCode)) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final all = data['all'] as List<dynamic>? ?? [];
      return all.map((p) => Provider.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get providers: ${response.statusCode}');
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
