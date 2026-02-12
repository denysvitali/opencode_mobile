import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/config.dart';
import '../models/session.dart';
import '../models/message.dart';
import '../models/permission.dart';

class OpenCodeClient {
  static final OpenCodeClient _instance = OpenCodeClient._();
  factory OpenCodeClient() => _instance;
  OpenCodeClient._();

  Dio? _dio;
  ServerConfig _config = ServerConfig();

  ServerConfig get config => _config;

  Future<void> initialize({required ServerConfig config}) async {
    _config = config;
    await _configureDio(config);
  }

  Future<void> _configureDio(ServerConfig config) async {
    final baseOptions = BaseOptions(
      baseUrl: config.url,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      contentType: 'application/json',
      responseType: ResponseType.json,
      validateStatus: (status) => true,
    );

    _dio = Dio(baseOptions);

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (config.hasAuth) {
            final credentials = base64Encode(
              utf8.encode('${config.username}:${config.password}'),
            );
            options.headers['Authorization'] = 'Basic $credentials';
          }
          options.headers['User-Agent'] = 'OpenCodeMobile/1.0';
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          debugPrint('Dio error: ${error.type} - ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> updateConfig(ServerConfig config) async {
    _config = config;
    _dio?.close(force: true);
    _dio = null;
    await _configureDio(config);
  }

  void _ensureInitialized() {
    if (_dio == null) {
      throw StateError('OpenCodeClient not initialized. Call initialize() first.');
    }
  }

  bool _isSuccess(Response response) {
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  Future<HealthCheckResult> healthCheck() async {
    _ensureInitialized();
    try {
      final response = await _dio!.get('/global/health');
      if (_isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        return HealthCheckResult(
          healthy: data['healthy'] as bool? ?? false,
          version: data['version'] as String?,
        );
      }
      return HealthCheckResult(healthy: false, error: 'Server returned ${response.statusCode}');
    } on DioException catch (e) {
      return HealthCheckResult(healthy: false, error: e.message);
    } catch (e) {
      return HealthCheckResult(healthy: false, error: e.toString());
    }
  }

  Future<List<Session>> listSessions({String? directory}) async {
    _ensureInitialized();
    final queryParams = <String, dynamic>{};
    if (directory != null) {
      queryParams['directory'] = directory;
    }
    final response = await _dio!.get('/session', queryParameters: queryParams);
    if (_isSuccess(response)) {
      final data = response.data as List<dynamic>;
      return data.map((s) => Session.fromJson(s as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to list sessions: ${response.statusCode}');
  }

  Future<Session> createSession({
    String? directory,
    String? title,
  }) async {
    _ensureInitialized();
    final response = await _dio!.post(
      '/session',
      data: {
        if (directory != null) 'directory': directory,
        if (title != null) 'title': title,
      },
    );
    if (_isSuccess(response)) {
      return Session.fromJson(response.data as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to create session: ${response.statusCode}');
  }

  Future<Session> getSession(String sessionId, {String? directory}) async {
    _ensureInitialized();
    final queryParams = <String, dynamic>{};
    if (directory != null) {
      queryParams['directory'] = directory;
    }
    final response = await _dio!.get(
      '/session/$sessionId',
      queryParameters: queryParams,
    );
    if (_isSuccess(response)) {
      return Session.fromJson(response.data as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to get session: ${response.statusCode}');
  }

  Future<void> deleteSession(String sessionId, {String? directory}) async {
    _ensureInitialized();
    final queryParams = <String, dynamic>{};
    if (directory != null) {
      queryParams['directory'] = directory;
    }
    final response = await _dio!.delete(
      '/session/$sessionId',
      queryParameters: queryParams,
    );
    if (!_isSuccess(response)) {
      throw OpenCodeException('Failed to delete session: ${response.statusCode}');
    }
  }

  Future<List<Message>> getMessages(String sessionId, {String? directory}) async {
    _ensureInitialized();
    final queryParams = <String, dynamic>{};
    if (directory != null) {
      queryParams['directory'] = directory;
    }
    final response = await _dio!.get(
      '/session/$sessionId/message',
      queryParameters: queryParams,
    );
    if (_isSuccess(response)) {
      final data = response.data as List<dynamic>;
      return data.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get messages: ${response.statusCode}');
  }

  Future<Message> sendMessage(
    String sessionId, {
    required String text,
    String? directory,
  }) async {
    _ensureInitialized();
    final response = await _dio!.post(
      '/session/$sessionId/message',
      queryParameters: directory != null ? {'directory': directory} : null,
      data: {
        'parts': [
          {'type': 'text', 'text': text}
        ]
      },
    );
    if (_isSuccess(response)) {
      return Message.fromJson(response.data as Map<String, dynamic>);
    }
    throw OpenCodeException('Failed to send message: ${response.statusCode}');
  }

  Stream<Message> sendMessageStream(
    String sessionId, {
    required String text,
    String? directory,
  }) async* {
    _ensureInitialized();
    final response = await _dio!.post(
      '/session/$sessionId/message',
      queryParameters: directory != null ? {'directory': directory} : null,
      data: {
        'parts': [
          {'type': 'text', 'text': text}
        ]
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
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
    _ensureInitialized();
    final response = await _dio!.post(
      '/session/$sessionId/abort',
      queryParameters: directory != null ? {'directory': directory} : null,
    );
    if (!_isSuccess(response)) {
      throw OpenCodeException('Failed to abort session: ${response.statusCode}');
    }
  }

  Future<List<Permission>> getPermissions({String? directory}) async {
    _ensureInitialized();
    final response = await _dio!.get(
      '/permission',
      queryParameters: directory != null ? {'directory': directory} : null,
    );
    if (_isSuccess(response)) {
      final data = response.data as List<dynamic>;
      return data.map((p) => Permission.fromJson(p as Map<String, dynamic>)).toList();
    }
    throw OpenCodeException('Failed to get permissions: ${response.statusCode}');
  }

  Future<void> replyPermission(
    String permissionId, {
    required PermissionReply reply,
    String? directory,
  }) async {
    _ensureInitialized();
    final response = await _dio!.post(
      '/permission/$permissionId/reply',
      queryParameters: directory != null ? {'directory': directory} : null,
      data: {'reply': reply.name},
    );
    if (!_isSuccess(response)) {
      throw OpenCodeException('Failed to reply to permission: ${response.statusCode}');
    }
  }

  void dispose() {
    _dio?.close(force: true);
    _dio = null;
  }
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
