import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_session.dart';

abstract class SessionStorage {
  Future<AppSession?> loadSession();
  Future<String?> loadLastServerUrl();
  Future<String?> loadLastUsername() async => null;
  Future<void> saveSession(AppSession session);
  Future<void> saveLastServerUrl(String serverUrl);
  Future<void> saveLastUsername(String username) async {}
  Future<void> clearSession();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _serverUrlKey = 'argocd.server_url';
  static const _lastUsernameKey = 'argocd.last_username';
  static const _tokenKey = 'argocd.token';
  static const _usernameKey = 'argocd.username';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<AppSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_serverUrlKey);
    final token = await _secureStorage.read(key: _tokenKey);
    final username = await _secureStorage.read(key: _usernameKey);

    if (serverUrl == null || token == null || username == null) {
      return null;
    }

    return AppSession(serverUrl: serverUrl, username: username, token: token);
  }

  @override
  Future<String?> loadLastServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  @override
  Future<String?> loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUsernameKey);
  }

  @override
  Future<void> saveSession(AppSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, session.serverUrl);
    await prefs.setString(_lastUsernameKey, session.username);
    await _secureStorage.write(key: _tokenKey, value: session.token);
    await _secureStorage.write(key: _usernameKey, value: session.username);
  }

  @override
  Future<void> saveLastServerUrl(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverUrl);
  }

  @override
  Future<void> saveLastUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsernameKey, username);
  }

  @override
  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _usernameKey);
  }
}
