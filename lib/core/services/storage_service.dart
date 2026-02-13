import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/config.dart';

class StorageService {
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  static const _keyServerUrl = 'server_url';
  static const _keyUsername = 'auth_username';
  static const _keyPassword = 'auth_password';
  static const _keyThemeMode = 'theme_mode';
  static const _keySelectedProviderId = 'selected_provider_id';
  static const _keySelectedModelId = 'selected_model_id';

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<ServerConfig> loadServerConfig() async {
    final url = _prefs?.getString(_keyServerUrl) ?? 'http://localhost:4096';
    final username = _prefs?.getString(_keyUsername);
    final password = await _secureStorage.read(key: _keyPassword);

    return ServerConfig(
      url: url,
      username: username,
      password: password,
    );
  }

  Future<void> saveServerConfig(ServerConfig config) async {
    await _prefs?.setString(_keyServerUrl, config.url);
    if (config.username != null) {
      await _prefs?.setString(_keyUsername, config.username!);
    } else {
      await _prefs?.remove(_keyUsername);
    }
    if (config.password != null) {
      await _secureStorage.write(key: _keyPassword, value: config.password);
    } else {
      await _secureStorage.delete(key: _keyPassword);
    }
  }

  Future<String?> getThemeMode() async {
    return _prefs?.getString(_keyThemeMode);
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs?.setString(_keyThemeMode, mode);
  }

  String? getSelectedProviderId() {
    return _prefs?.getString(_keySelectedProviderId);
  }

  String? getSelectedModelId() {
    return _prefs?.getString(_keySelectedModelId);
  }

  Future<void> saveModelSelection(String? providerId, String? modelId) async {
    if (providerId != null) {
      await _prefs?.setString(_keySelectedProviderId, providerId);
    } else {
      await _prefs?.remove(_keySelectedProviderId);
    }
    if (modelId != null) {
      await _prefs?.setString(_keySelectedModelId, modelId);
    } else {
      await _prefs?.remove(_keySelectedModelId);
    }
  }
}
