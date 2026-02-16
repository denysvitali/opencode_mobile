import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cronet_http/cronet_http.dart';

class PlatformHttpClient {
  http.Client? _cronetClient;
  http.Client? _fallbackClient;
  http.Client? _testClient;
  bool _cronetFailed = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (Platform.isAndroid) {
      try {
        final engine = CronetEngine.build(
          cacheMode: CacheMode.memory,
          userAgent: 'OpenCodeMobile/1.0',
        );
        _cronetClient = CronetClient.fromCronetEngine(engine, closeEngine: true);
        if (kDebugMode) {
          print('HTTP: Cronet initialized successfully');
        }
      } catch (e) {
        _cronetFailed = true;
        _fallbackClient = http.Client();
        if (kDebugMode) {
          print('HTTP: Cronet failed to initialize: $e, using fallback');
        }
      }
    } else {
      _fallbackClient = http.Client();
    }
  }

  http.Client get client {
    if (_testClient != null) return _testClient!;
    if (Platform.isAndroid && _cronetClient != null && !_cronetFailed) {
      return _cronetClient!;
    }
    return _fallbackClient ?? http.Client();
  }

  void setTestClient(http.Client? client) {
    _testClient = client;
  }

  bool get isUsingCronet => Platform.isAndroid && _cronetClient != null && !_cronetFailed;
  
  bool get hasCronetFailed => _cronetFailed;

  void close() {
    _cronetClient?.close();
    _fallbackClient?.close();
  }
}

final platformHttpClient = PlatformHttpClient();
