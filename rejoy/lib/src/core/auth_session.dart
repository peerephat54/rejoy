import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static const _tokenKey = 'rejoy_auth_token';
  static const _refreshTokenKey = 'rejoy_refresh_token';
  static const _userIdKey = 'rejoy_auth_user_id';
  static const _emailKey = 'rejoy_auth_email';
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
    _token = await _secureStorage.read(key: _tokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    _userId = prefs.getString(_userIdKey);
    _email = prefs.getString(_emailKey);

    final legacyToken = prefs.getString(_tokenKey);
    if (_token == null && legacyToken != null) {
      _token = legacyToken;
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
    }
  }

  static Future<void> save({
    required String token,
    String? refreshToken,
    required String userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _tokenKey, value: token);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      _refreshToken = refreshToken;
    }
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_emailKey, email);
    _token = token;
    _userId = userId;
    _email = email;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    _token = null;
    _refreshToken = null;
    _userId = null;
    _email = null;
  }
}
