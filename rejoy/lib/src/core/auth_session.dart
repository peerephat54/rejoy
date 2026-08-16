import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static const inactivityLimit = Duration(minutes: 15);
  static const _tokenKey = 'rejoy_auth_token';
  static const _refreshTokenKey = 'rejoy_refresh_token';
  static const _userIdKey = 'rejoy_auth_user_id';
  static const _emailKey = 'rejoy_auth_email';
  static const _lastActiveAtKey = 'rejoy_last_active_at';
  static const _secureStorage = FlutterSecureStorage();

  static String? _token;
  static String? _refreshToken;
  static String? _userId;
  static String? _email;

  static String? get token => _token;
  static String? get refreshToken => _refreshToken;
  static String? get userId => _userId;
  static String? get email => _email;
  static bool get isSignedIn => _token != null && _userId != null;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _token = await _secureStorage.read(key: _tokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    } catch (_) {
      // Demo/debug APKs on some Android devices can fail secure-storage init.
      // Fall back to local prefs so the app remains usable for presentation.
      _token = prefs.getString(_tokenKey);
      _refreshToken = prefs.getString(_refreshTokenKey);
    }
    _userId = prefs.getString(_userIdKey);
    _email = prefs.getString(_emailKey);

    if (await isExpired()) {
      await clear();
      return;
    }

    final legacyToken = prefs.getString(_tokenKey);
    if (_token == null && legacyToken != null) {
      _token = legacyToken;
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
    }

    if (isSignedIn) {
      await touch();
    }
  }

  static Future<void> save({
    required String token,
    String? refreshToken,
    required String userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      await prefs.setString(_tokenKey, token);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      } catch (_) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
      _refreshToken = refreshToken;
    }
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_emailKey, email);
    await prefs.setInt(_lastActiveAtKey, DateTime.now().millisecondsSinceEpoch);
    _token = token;
    _userId = userId;
    _email = email;
  }

  static Future<void> touch() async {
    if (!isSignedIn) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActiveAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> isExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActiveAt = prefs.getInt(_lastActiveAtKey);
    if (lastActiveAt == null) return false;
    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveAt);
    return DateTime.now().difference(lastActive) >= inactivityLimit;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (_) {
      // Ignore secure-storage cleanup failures and still clear local session.
    }
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_lastActiveAtKey);
    _token = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
  }
}
