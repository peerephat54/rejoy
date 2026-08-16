import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _cloudBaseUrl = 'https://rejoy-backend.onrender.com';
  static const _overrideKey = 'rejoy_api_base_url';
  static String? _savedBaseUrl;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_overrideKey)?.trim();
    const envBaseUrl = String.fromEnvironment(
      'REJOY_API_BASE_URL',
      defaultValue: '',
    );
    if (envBaseUrl.isNotEmpty || _isLocalDevelopmentUrl(saved)) {
      await prefs.remove(_overrideKey);
      _savedBaseUrl = null;
      return;
    }
    if (saved != null && saved.isNotEmpty) {
      _savedBaseUrl = _normalizeBaseUrl(saved);
    }
  }

  static Future<void> saveBaseUrlOverride(String value) async {
    final normalized = _normalizeBaseUrl(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overrideKey, normalized);
    _savedBaseUrl = normalized;
  }

  static Future<void> clearBaseUrlOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_overrideKey);
    _savedBaseUrl = null;
  }

  static String get configuredBaseUrl => _savedBaseUrl ?? baseUrl;

  static String get baseUrl {
    const envBaseUrl = String.fromEnvironment(
      'REJOY_API_BASE_URL',
      defaultValue: '',
    );
    if (envBaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(envBaseUrl);
    }

    if (_savedBaseUrl != null && _savedBaseUrl!.isNotEmpty) {
      return _savedBaseUrl!;
    }

    // Real builds must not depend on a developer machine.
    // Debug keeps local endpoints so day-to-day development stays fast.
    if (!kDebugMode || kIsWeb) {
      return _cloudBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://localhost:3000';
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000';
    }
  }

  static String _normalizeBaseUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static bool _isLocalDevelopmentUrl(String? value) {
    final url = value?.trim().toLowerCase() ?? '';
    return url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.contains('10.0.2.2');
  }

  static Uri healthUri() => Uri.parse('$baseUrl/api/health');
  static Uri usersUri() => Uri.parse('$baseUrl/api/users');
  static Uri activeClinicalProfileUri() =>
      Uri.parse('$baseUrl/api/users/active/profile');
  static Uri questsUri() => Uri.parse('$baseUrl/api/quests');
  static Uri reportsUri() => Uri.parse('$baseUrl/api/reports');
  static Uri companionChatUri() => Uri.parse('$baseUrl/api/chat/companion');
  static Uri clinicalDashboardUri() =>
      Uri.parse('$baseUrl/api/clinical/dashboard');
  static Uri clinicalCarePlansUri() =>
      Uri.parse('$baseUrl/api/clinical/care-plans');
  static Uri authRegisterUri() => Uri.parse('$baseUrl/api/auth/register');
  static Uri authLoginUri() => Uri.parse('$baseUrl/api/auth/login');
  static Uri authRefreshUri() => Uri.parse('$baseUrl/api/auth/refresh');
  static Uri authLogoutUri() => Uri.parse('$baseUrl/api/auth/logout');
  static Uri authMeUri() => Uri.parse('$baseUrl/api/auth/me');
  static Uri reportGenerateUri(String userId) =>
      Uri.parse('$baseUrl/api/reports/generate/$userId');
  static Uri userReportsUri(String userId) =>
      Uri.parse('$baseUrl/api/reports/user/$userId');
  static Uri userMoodLogUri(String userId) =>
      Uri.parse('$baseUrl/api/users/$userId/mood-log');
  static Uri userPhq9HistoryUri(String userId) =>
      Uri.parse('$baseUrl/api/users/$userId/phq9-history');
  static Uri userSymptomMatrixHistoryUri(String userId) =>
      Uri.parse('$baseUrl/api/users/$userId/symptom-matrix-history');
}
