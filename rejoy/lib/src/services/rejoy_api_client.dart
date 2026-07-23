import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/auth_session.dart';

class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.service,
    required this.database,
    required this.timestamp,
    required this.uptimeSeconds,
  });

  final String status;
  final String service;
  final String database;
  final DateTime? timestamp;
  final int? uptimeSeconds;

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    return BackendHealth(
      status: json['status']?.toString() ?? 'unknown',
      service: json['service']?.toString() ?? 'unknown',
      database: json['database']?.toString() ?? 'unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
      uptimeSeconds: json['uptimeSeconds'] is int
          ? json['uptimeSeconds'] as int
          : int.tryParse(json['uptimeSeconds']?.toString() ?? ''),
    );
  }
}

class BackendUser {
  const BackendUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.surname,
    required this.age,
    required this.allergies,
    required this.medicalHistory,
    required this.emergencyContactNumbers,
    required this.currentMedications,
    required this.symptomClusteringMatrix,
    required this.completedQuestsCount,
    required this.unlockedAnimals,
    required this.animalNicknames,
    required this.currentEnergyLevel,
    required this.selectedQuestsToday,
    required this.completedQuestsToday,
    required this.onboardingComplete,
  });

  final String id;
  final String email;
  final String firstName;
  final String surname;
  final int age;
  final List<String> allergies;
  final String medicalHistory;
  final List<String> emergencyContactNumbers;
  final List<String> currentMedications;
  final List<String> symptomClusteringMatrix;
  final int completedQuestsCount;
  final List<String> unlockedAnimals;
  final Map<String, String> animalNicknames;
  final String currentEnergyLevel;
  final List<String> selectedQuestsToday;
  final List<String> completedQuestsToday;
  final bool onboardingComplete;

  String get fullName => '$firstName $surname'.trim();
  int get questsUntilNextAnimal {
    final remainder = completedQuestsCount % 3;
    return remainder == 0 ? 3 : 3 - remainder;
  }

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    final unlockedAnimalsValue = json['unlockedAnimals'];
    final animalNicknamesValue = json['animalNicknames'];
    final selectedQuestsTodayValue = json['selectedQuestsToday'];
    final completedQuestsTodayValue = json['completedQuestsToday'];
    final allergiesValue = json['allergies'];
    final emergencyContactNumbersValue = json['emergencyContactNumbers'];
    final currentMedicationsValue = json['currentMedications'];
    final symptomClusteringMatrixValue = json['symptomClusteringMatrix'];
    return BackendUser(
      id: json['_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      surname: json['surname']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
      allergies: allergiesValue is List
          ? allergiesValue.map((item) => item.toString()).toList()
          : <String>[],
      medicalHistory: json['medicalHistory']?.toString() ?? '',
      emergencyContactNumbers: emergencyContactNumbersValue is List
          ? emergencyContactNumbersValue.map((item) => item.toString()).toList()
          : <String>[],
      currentMedications: currentMedicationsValue is List
          ? currentMedicationsValue.map((item) => item.toString()).toList()
          : <String>[],
      symptomClusteringMatrix: symptomClusteringMatrixValue is List
          ? symptomClusteringMatrixValue.map((item) => item.toString()).toList()
          : <String>[],
      completedQuestsCount:
          int.tryParse(json['completedQuestsCount']?.toString() ?? '') ?? 0,
      unlockedAnimals: unlockedAnimalsValue is List
          ? unlockedAnimalsValue.map((item) => item.toString()).toList()
          : <String>[],
      animalNicknames: animalNicknamesValue is Map
          ? animalNicknamesValue.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : <String, String>{},
      currentEnergyLevel: json['currentEnergyLevel']?.toString() ?? 'rest',
      selectedQuestsToday: selectedQuestsTodayValue is List
          ? selectedQuestsTodayValue.map((item) => item.toString()).toList()
          : <String>[],
      completedQuestsToday: completedQuestsTodayValue is List
          ? completedQuestsTodayValue.map((item) => item.toString()).toList()
          : <String>[],
      onboardingComplete:
          json['onboardingComplete'] == true ||
          json['onboardingComplete']?.toString() == 'true',
    );
  }
}

class QuestItem {
  const QuestItem({
    required this.id,
    required this.name,
    required this.description,
    required this.energyLevel,
    required this.reward,
    required this.animalId,
    required this.color,
    required this.isActive,
  });

  final String id;
  final String name;
  final String description;
  final String energyLevel;
  final String reward;
  final String animalId;
  final String color;
  final bool isActive;

  factory QuestItem.fromJson(Map<String, dynamic> json) {
    return QuestItem(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      energyLevel: json['energyLevel']?.toString() ?? '',
      reward: json['reward']?.toString() ?? '',
      animalId: json['animalId']?.toString() ?? '',
      color: json['color']?.toString() ?? '#5A8DEE',
      isActive:
          json['isActive'] == true || json['isActive']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'energyLevel': energyLevel,
      'reward': reward,
      'animalId': animalId,
      'color': color,
      'isActive': isActive,
    };
  }
}

class QuestCompletionResult {
  const QuestCompletionResult({
    required this.message,
    required this.unlockedAnimal,
    required this.questsUntilNextAnimal,
    required this.completedQuestsCount,
    required this.unlockedAnimals,
    required this.user,
  });

  final String message;
  final String unlockedAnimal;
  final int questsUntilNextAnimal;
  final int completedQuestsCount;
  final List<String> unlockedAnimals;
  final BackendUser? user;

  factory QuestCompletionResult.fromJson(Map<String, dynamic> json) {
    final unlockedAnimalsValue = json['unlockedAnimals'];
    final unlockedAnimals = unlockedAnimalsValue is List
        ? unlockedAnimalsValue.map((item) => item.toString()).toList()
        : <String>[];
    final userJson = json['user'];

    return QuestCompletionResult(
      message: json['message']?.toString() ?? 'Quest completed.',
      unlockedAnimal: json['unlockedAnimal']?.toString() ?? '',
      questsUntilNextAnimal:
          int.tryParse(json['questsUntilNextAnimal']?.toString() ?? '') ?? 3,
      completedQuestsCount:
          int.tryParse(json['completedQuestsCount']?.toString() ?? '') ?? 0,
      unlockedAnimals: unlockedAnimals,
      user: userJson is Map<String, dynamic>
          ? BackendUser.fromJson(userJson)
          : null,
    );
  }
}

class QuestDayFinishResult {
  const QuestDayFinishResult({
    required this.message,
    required this.totalSelectedQuests,
    required this.completedQuestsCount,
    required this.completionRate,
    required this.unlockedAnimalsToday,
    required this.companionMessage,
    required this.questsUntilNextAnimal,
    required this.user,
  });

  final String message;
  final int totalSelectedQuests;
  final int completedQuestsCount;
  final String completionRate;
  final List<String> unlockedAnimalsToday;
  final String companionMessage;
  final int questsUntilNextAnimal;
  final BackendUser? user;

  factory QuestDayFinishResult.fromJson(Map<String, dynamic> json) {
    final unlockedAnimalsValue = json['unlocked_animals_today'];
    final userJson = json['user'];
    return QuestDayFinishResult(
      message: json['message']?.toString() ?? 'Day finished.',
      totalSelectedQuests:
          int.tryParse(json['total_selected_quests']?.toString() ?? '') ?? 0,
      completedQuestsCount:
          int.tryParse(json['completed_quests_count']?.toString() ?? '') ?? 0,
      completionRate: json['completed_quests_rate']?.toString() ?? '0/0',
      unlockedAnimalsToday: unlockedAnimalsValue is List
          ? unlockedAnimalsValue.map((item) => item.toString()).toList()
          : <String>[],
      companionMessage: json['companion_message']?.toString() ?? '',
      questsUntilNextAnimal:
          int.tryParse(json['questsUntilNextAnimal']?.toString() ?? '') ?? 3,
      user: userJson is Map<String, dynamic>
          ? BackendUser.fromJson(userJson)
          : null,
    );
  }
}

class ReportSymptomMatrix {
  const ReportSymptomMatrix({
    required this.moodScore,
    required this.somaticScore,
    required this.behavioralScore,
  });

  final int moodScore;
  final int somaticScore;
  final int behavioralScore;

  factory ReportSymptomMatrix.fromJson(Map<String, dynamic> json) {
    return ReportSymptomMatrix(
      moodScore: int.tryParse(json['mood_score']?.toString() ?? '') ?? 0,
      somaticScore: int.tryParse(json['somatic_score']?.toString() ?? '') ?? 0,
      behavioralScore:
          int.tryParse(json['behavioral_score']?.toString() ?? '') ?? 0,
    );
  }
}

class ReportEntry {
  const ReportEntry({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.date,
    required this.phq9Score,
    required this.symptomMatrix,
    required this.dailyMood,
    required this.diaryNote,
    required this.cbtCompletionRate,
    required this.unlockedAnimalToday,
    required this.isRestDay,
    required this.isSosTriggered,
    required this.periodDays,
  });

  final String id;
  final String reportId;
  final String userId;
  final DateTime? date;
  final int phq9Score;
  final ReportSymptomMatrix symptomMatrix;
  final String dailyMood;
  final String diaryNote;
  final String cbtCompletionRate;
  final String unlockedAnimalToday;
  final bool isRestDay;
  final bool isSosTriggered;
  final int periodDays;

  factory ReportEntry.fromJson(Map<String, dynamic> json) {
    final userIdValue = json['userId'];
    final String userId = userIdValue is Map
        ? userIdValue['_id']?.toString() ?? ''
        : userIdValue?.toString() ?? '';
    final symptomMatrixJson = json['symptomMatrix'];

    return ReportEntry(
      id: json['_id']?.toString() ?? '',
      reportId: json['reportId']?.toString() ?? '',
      userId: userId,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      phq9Score: int.tryParse(json['phq9Score']?.toString() ?? '') ?? 0,
      symptomMatrix: symptomMatrixJson is Map<String, dynamic>
          ? ReportSymptomMatrix.fromJson(symptomMatrixJson)
          : const ReportSymptomMatrix(
              moodScore: 0,
              somaticScore: 0,
              behavioralScore: 0,
            ),
      dailyMood: json['dailyMood']?.toString() ?? '',
      diaryNote: json['diaryNote']?.toString() ?? '',
      cbtCompletionRate: json['cbtCompletionRate']?.toString() ?? '0%',
      unlockedAnimalToday: json['unlockedAnimalToday']?.toString() ?? '',
      isRestDay:
          json['isRestDay'] == true || json['isRestDay']?.toString() == 'true',
      isSosTriggered:
          json['isSosTriggered'] == true ||
          json['isSosTriggered']?.toString() == 'true',
      periodDays: int.tryParse(json['periodDays']?.toString() ?? '') ?? 14,
    );
  }
}

class CompanionReply {
  const CompanionReply({required this.provider, required this.message});

  final String provider;
  final String message;

  factory CompanionReply.fromJson(Map<String, dynamic> json) {
    return CompanionReply(
      provider: json['provider']?.toString() ?? 'fallback',
      message: json['message']?.toString() ?? '',
    );
  }
}

class ClinicalProfilePayload {
  const ClinicalProfilePayload({required this.user, required this.reports});

  final BackendUser user;
  final List<ReportEntry> reports;

  factory ClinicalProfilePayload.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final reportsJson = json['reports'];

    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid clinical profile user payload');
    }

    return ClinicalProfilePayload(
      user: BackendUser.fromJson(userJson),
      reports: reportsJson is List
          ? reportsJson
                .whereType<Map>()
                .map(
                  (item) =>
                      ReportEntry.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <ReportEntry>[],
    );
  }
}

class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final String token;
  final String refreshToken;
  final BackendUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth user payload');
    }
    return AuthResponse(
      token: json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: BackendUser.fromJson(userJson),
    );
  }
}

class _AuthHttpClient extends http.BaseClient {
  _AuthHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final retryRequest = request is http.Request
        ? _cloneRequest(request)
        : null;
    _attachToken(request);

    final response = await _inner.send(request);
    if (response.statusCode != 401 || retryRequest == null) {
      return response;
    }

    final refreshed = await _refreshAuthToken();
    if (!refreshed) {
      return response;
    }

    await response.stream.drain<void>();
    _attachToken(retryRequest, replace: true);
    return _inner.send(retryRequest);
  }

  @override
  void close() {
    _inner.close();
  }

  void _attachToken(http.BaseRequest request, {bool replace = false}) {
    final token = AuthSession.token;
    if (token == null || token.isEmpty) return;
    if (replace) {
      request.headers['authorization'] = 'Bearer $token';
    } else {
      request.headers.putIfAbsent('authorization', () => 'Bearer $token');
    }
  }

  http.Request _cloneRequest(http.Request request) {
    final clone = http.Request(request.method, request.url)
      ..bodyBytes = request.bodyBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    clone.headers.addAll(request.headers);
    return clone;
  }

  Future<bool> _refreshAuthToken() async {
    final refreshToken = AuthSession.refreshToken;
    final userId = AuthSession.userId;
    final email = AuthSession.email;
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        userId == null ||
        email == null) {
      return false;
    }

    try {
      final response = await _inner
          .post(
            ApiConfig.authRefreshUri(),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await AuthSession.clear();
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final auth = AuthResponse.fromJson(decoded);
      await AuthSession.save(
        token: auth.token,
        refreshToken: auth.refreshToken,
        userId: auth.user.id.isEmpty ? userId : auth.user.id,
        email: auth.user.email.isEmpty ? email : auth.user.email,
      );
      ReJoyApiClient.clearCache();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _TimedCache<T> {
  const _TimedCache(this.value, this.createdAt);

  final T value;
  final DateTime createdAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

class ReJoyApiClient {
  ReJoyApiClient({http.Client? httpClient})
    : _http = _AuthHttpClient(httpClient ?? http.Client());

  static const _profileCacheTtl = Duration(seconds: 30);
  static const _reportCacheTtl = Duration(seconds: 20);
  static const _questCacheTtl = Duration(minutes: 5);
  static const _storedQuestCacheTtl = Duration(hours: 12);
  static const _questCachePrefix = 'rejoy_quests_cache_v2';

  static _TimedCache<ClinicalProfilePayload>? _activeProfileCache;
  static final Map<String, _TimedCache<List<QuestItem>>> _questCache = {};
  static final Map<String, _TimedCache<List<ReportEntry>>> _reportCache = {};

  final http.Client _http;

  static void clearCache() {
    _activeProfileCache = null;
    _questCache.clear();
    _reportCache.clear();
  }

  static void _invalidateUserCaches() {
    _activeProfileCache = null;
    _reportCache.clear();
  }

  static String _questStorageKey(String cacheKey) =>
      '${_questCachePrefix}_$cacheKey';

  static String _questStorageTimeKey(String cacheKey) =>
      '${_questStorageKey(cacheKey)}_saved_at';

  static Future<List<QuestItem>?> _loadStoredQuests(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getInt(_questStorageTimeKey(cacheKey));
    final raw = prefs.getString(_questStorageKey(cacheKey));
    if (savedAt == null || raw == null || raw.isEmpty) {
      return null;
    }

    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(savedAt),
    );
    if (age > _storedQuestCacheTtl) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return null;
    }

    return decoded
        .whereType<Map>()
        .map((item) => QuestItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> _saveStoredQuests(
    String cacheKey,
    List<QuestItem> quests,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _questStorageTimeKey(cacheKey),
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
      _questStorageKey(cacheKey),
      jsonEncode(quests.map((quest) => quest.toJson()).toList()),
    );
  }

  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String surname,
    required int age,
  }) async {
    final response = await _http
        .post(
          ApiConfig.authRegisterUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'email': email,
            'password': password,
            'firstName': firstName,
            'surname': surname,
            'age': age,
          }),
        )
        .timeout(const Duration(seconds: 45));

    clearCache();
    return _decodeJsonObject(
      response,
      (json) => AuthResponse.fromJson(json),
      'Register failed',
    );
  }

  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _http
        .post(
          ApiConfig.authLoginUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 45));

    clearCache();
    return _decodeJsonObject(
      response,
      (json) => AuthResponse.fromJson(json),
      'Login failed',
    );
  }

  Future<void> logout() async {
    final refreshToken = AuthSession.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }

    final response = await _http
        .post(
          ApiConfig.authLogoutUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 8));

    await _decodeJsonObject(response, (json) => json, 'Logout failed');
  }

  Future<BackendHealth> fetchHealth() async {
    final response = await _http
        .get(ApiConfig.healthUri(), headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 6));

    return _decodeJsonObject(
      response,
      (json) => BackendHealth.fromJson(json),
      'Health request failed',
    );
  }

  Future<Map<String, dynamic>> fetchClinicalDashboard() async {
    final response = await _http
        .get(
          ApiConfig.clinicalDashboardUri(),
          headers: {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));

    return _decodeJsonObject(
      response,
      (json) => json,
      'Clinical dashboard request failed',
    );
  }

  Future<Map<String, dynamic>> createCarePlan({
    required String title,
    required String focusArea,
    required String recommendedQuestEnergy,
    String? userId,
    String? note,
  }) async {
    final response = await _http
        .post(
          ApiConfig.clinicalCarePlansUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'title': title,
            'focusArea': focusArea,
            'recommendedQuestEnergy': recommendedQuestEnergy,
            if (userId != null && userId.isNotEmpty) 'userId': userId,
            if (note != null && note.isNotEmpty) 'note': note,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final result = await _decodeJsonObject(
      response,
      (json) => json,
      'Create care plan failed',
    );
    _invalidateUserCaches();
    return result;
  }

  Future<List<BackendUser>> fetchUsers() async {
    final response = await _http
        .get(ApiConfig.usersUri(), headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 6));

    return _decodeJsonList(
      response,
      (json) => BackendUser.fromJson(json),
      'Users request failed',
    );
  }

  Future<BackendUser> updateUserProfile({
    required String userId,
    required String firstName,
    required String surname,
    required int age,
    required List<String> allergies,
    required List<String> emergencyContactNumbers,
    required List<String> currentMedications,
    required String medicalHistory,
    bool? onboardingComplete,
  }) async {
    final response = await _http
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/users/$userId'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'firstName': firstName,
            'surname': surname,
            'age': age,
            'allergies': allergies,
            'emergencyContactNumbers': emergencyContactNumbers,
            'currentMedications': currentMedications,
            'medicalHistory': medicalHistory,
            if (onboardingComplete != null)
              'onboardingComplete': onboardingComplete,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final user = await _decodeJsonObject(
      response,
      (json) => BackendUser.fromJson(json),
      'Update user profile failed',
    );
    _invalidateUserCaches();
    return user;
  }

  Future<BackendUser> saveAnimalNickname({
    required BackendUser user,
    required String animalId,
    required String nickname,
  }) async {
    final nicknames = Map<String, String>.from(user.animalNicknames);
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      nicknames.remove(animalId);
    } else {
      nicknames[animalId] = trimmed;
    }

    final response = await _http
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/users/${user.id}'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'animalNicknames': nicknames}),
        )
        .timeout(const Duration(seconds: 6));

    final updatedUser = await _decodeJsonObject(
      response,
      (json) => BackendUser.fromJson(json),
      'Save animal nickname failed',
    );
    _invalidateUserCaches();
    return updatedUser;
  }

  Future<ClinicalProfilePayload> fetchActiveClinicalProfile({
    bool forceRefresh = false,
  }) async {
    final cached = _activeProfileCache;
    if (!forceRefresh && cached != null && cached.isFresh(_profileCacheTtl)) {
      return cached.value;
    }

    final response = await _http
        .get(
          ApiConfig.activeClinicalProfileUri(),
          headers: {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 6));

    final payload = await _decodeJsonObject(
      response,
      (json) => ClinicalProfilePayload.fromJson(json),
      'Clinical profile request failed',
    );
    _activeProfileCache = _TimedCache(payload, DateTime.now());
    return payload;
  }

  Future<CompanionReply> sendCompanionMessage({
    required String message,
    required List<Map<String, String>> history,
    String? topic,
  }) async {
    final response = await _http
        .post(
          ApiConfig.companionChatUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'message': message,
            'history': history,
            if (topic != null && topic.isNotEmpty) 'topic': topic,
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _decodeJsonObject(
      response,
      (json) => CompanionReply.fromJson(json),
      'Companion chat failed',
    );
  }

  Future<void> appendMoodLog({
    required String userId,
    required int moodLevel,
  }) async {
    final response = await _http
        .post(
          ApiConfig.userMoodLogUri(userId),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'mood_level': moodLevel}),
        )
        .timeout(const Duration(seconds: 6));

    await _decodeJsonObject(response, (json) => json, 'Mood log failed');
    _invalidateUserCaches();
  }

  Future<void> appendPhq9Log({
    required String userId,
    required int totalScore,
  }) async {
    final response = await _http
        .post(
          ApiConfig.userPhq9HistoryUri(userId),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'total_score': totalScore}),
        )
        .timeout(const Duration(seconds: 6));

    await _decodeJsonObject(response, (json) => json, 'PHQ-9 log failed');
    _invalidateUserCaches();
  }

  Future<void> appendSymptomMatrixLog({
    required String userId,
    required int moodScore,
    required int somaticScore,
    required int behavioralScore,
  }) async {
    final response = await _http
        .post(
          ApiConfig.userSymptomMatrixHistoryUri(userId),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'mood_score': moodScore,
            'somatic_score': somaticScore,
            'behavioral_score': behavioralScore,
          }),
        )
        .timeout(const Duration(seconds: 6));

    await _decodeJsonObject(
      response,
      (json) => json,
      'Symptom matrix log failed',
    );
    _invalidateUserCaches();
  }

  Future<List<QuestItem>> fetchQuests({
    String? energyLevel,
    bool forceRefresh = false,
  }) async {
    final cacheKey = energyLevel == null || energyLevel.isEmpty
        ? 'all'
        : energyLevel;
    final cached = _questCache[cacheKey];
    if (!forceRefresh && cached != null && cached.isFresh(_questCacheTtl)) {
      return cached.value;
    }

    if (!forceRefresh) {
      final storedQuests = await _loadStoredQuests(cacheKey);
      if (storedQuests != null) {
        _questCache[cacheKey] = _TimedCache(storedQuests, DateTime.now());
        return storedQuests;
      }
    }

    final uri = energyLevel == null || energyLevel.isEmpty
        ? ApiConfig.questsUri().replace(queryParameters: {'limit': '10'})
        : ApiConfig.questsUri().replace(
            queryParameters: {'energyLevel': energyLevel, 'limit': '10'},
          );

    final response = await _http
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 6));

    final quests = await _decodeJsonList(
      response,
      (json) => QuestItem.fromJson(json),
      'Quests request failed',
    );
    _questCache[cacheKey] = _TimedCache(quests, DateTime.now());
    await _saveStoredQuests(cacheKey, quests);
    return quests;
  }

  Future<List<ReportEntry>> fetchReports({
    String? userId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = userId == null || userId.isEmpty ? 'all' : userId;
    final cached = _reportCache[cacheKey];
    if (!forceRefresh && cached != null && cached.isFresh(_reportCacheTtl)) {
      return cached.value;
    }

    final uri = userId == null || userId.isEmpty
        ? ApiConfig.reportsUri()
        : ApiConfig.userReportsUri(userId);

    final response = await _http
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(const Duration(seconds: 6));

    final reports = await _decodeJsonList(
      response,
      (json) => ReportEntry.fromJson(json),
      'Reports request failed',
    );
    _reportCache[cacheKey] = _TimedCache(reports, DateTime.now());
    return reports;
  }

  Future<ReportEntry> updateReport({
    required String reportId,
    String? diaryNote,
    String? dailyMood,
    String? cbtCompletionRate,
    String? unlockedAnimalToday,
    bool? isRestDay,
    bool? isSosTriggered,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{
      if (diaryNote != null) 'diaryNote': diaryNote,
      if (dailyMood != null) 'dailyMood': dailyMood,
      if (cbtCompletionRate != null) 'cbtCompletionRate': cbtCompletionRate,
      if (unlockedAnimalToday != null)
        'unlockedAnimalToday': unlockedAnimalToday,
      if (isRestDay != null) 'isRestDay': isRestDay,
      if (isSosTriggered != null) 'isSosTriggered': isSosTriggered,
      if (date != null) 'date': date.toIso8601String(),
    };

    final response = await _http
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/reports/$reportId'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    final report = await _decodeJsonObject(
      response,
      (json) => ReportEntry.fromJson(json),
      'Update report failed',
    );
    _invalidateUserCaches();
    return report;
  }

  Future<ReportEntry> generateReportForUser(String userId) async {
    final response = await _http
        .post(
          ApiConfig.reportGenerateUri(userId),
          headers: {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 6));

    final report = await _decodeJsonObject(
      response,
      (json) => ReportEntry.fromJson(json),
      'Generate report failed',
    );
    _invalidateUserCaches();
    return report;
  }

  Future<QuestCompletionResult> completeQuestForUser({
    required String userId,
    required String questName,
    String? questAnimalId,
    String? energyModeSelected,
    String? completionRate,
    bool? isRestDay,
  }) async {
    final body = <String, dynamic>{
      'quest_name': questName,
      if (questAnimalId != null) 'quest_animal_id': questAnimalId,
      if (energyModeSelected != null)
        'energy_mode_selected': energyModeSelected,
      if (completionRate != null) 'completion_rate': completionRate,
      if (isRestDay != null) 'is_rest_day': isRestDay,
    };

    final response = await _http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/quest-complete'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    final result = await _decodeJsonObject(
      response,
      (json) => QuestCompletionResult.fromJson(json),
      'Complete quest failed',
    );
    _invalidateUserCaches();
    return result;
  }

  Future<QuestDayFinishResult> finishQuestDayForUser({
    required String userId,
    required List<String> selectedQuests,
    required List<String> completedQuests,
    String? energyModeSelected,
    String? completionRate,
    bool? isRestDay,
  }) async {
    final body = <String, dynamic>{
      'selected_quests': selectedQuests,
      'completed_quests': completedQuests,
      if (energyModeSelected != null)
        'energy_mode_selected': energyModeSelected,
      if (completionRate != null) 'completion_rate': completionRate,
      if (isRestDay != null) 'is_rest_day': isRestDay,
    };

    final response = await _http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/quest-day/finish'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    final result = await _decodeJsonObject(
      response,
      (json) => QuestDayFinishResult.fromJson(json),
      'Finish quest day failed',
    );
    _invalidateUserCaches();
    return result;
  }

  Future<void> savePositiveMemoryForUser({
    required String userId,
    required String answer,
    String? prompt,
    String? animalId,
    String? moodState,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{
      'answer': answer,
      if (prompt != null) 'prompt': prompt,
      if (animalId != null) 'animal_id': animalId,
      if (moodState != null) 'mood_state': moodState,
      if (date != null) 'date': date.toIso8601String(),
    };

    final response = await _http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/positive-memory'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    await _decodeJsonObject(response, (json) => json, 'Save memory failed');
    _invalidateUserCaches();
  }

  Future<ReportEntry> createReportForUser({
    required String userId,
    int? phq9Score,
    Map<String, dynamic>? symptomMatrix,
    String? dailyMood,
    String? diaryNote,
    String? cbtCompletionRate,
    String? unlockedAnimalToday,
    bool? isRestDay,
    bool? isSosTriggered,
    int? periodDays,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final body = <String, dynamic>{
      'userId': userId,
      if (phq9Score != null) 'phq9Score': phq9Score,
      if (symptomMatrix != null) 'symptomMatrix': symptomMatrix,
      if (dailyMood != null) 'dailyMood': dailyMood,
      if (diaryNote != null) 'diaryNote': diaryNote,
      if (cbtCompletionRate != null) 'cbtCompletionRate': cbtCompletionRate,
      if (unlockedAnimalToday != null)
        'unlockedAnimalToday': unlockedAnimalToday,
      if (isRestDay != null) 'isRestDay': isRestDay,
      if (isSosTriggered != null) 'isSosTriggered': isSosTriggered,
      if (periodDays != null) 'periodDays': periodDays,
      if (date != null) 'date': date.toIso8601String(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };

    final response = await _http
        .post(
          ApiConfig.reportsUri(),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    final report = await _decodeJsonObject(
      response,
      (json) => ReportEntry.fromJson(json),
      'Create report failed',
    );
    _invalidateUserCaches();
    return report;
  }

  Future<List<BackendUser>> fetchUsersOrSeed() async {
    final users = await fetchUsers();
    if (users.isNotEmpty) {
      return users;
    }
    throw StateError('No users found. Create a user first.');
  }

  Future<T> _decodeJsonObject<T>(
    http.Response response,
    T Function(Map<String, dynamic> json) builder,
    String errorPrefix,
  ) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        '$errorPrefix with ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid response format');
    }

    return builder(jsonBody);
  }

  Future<List<T>> _decodeJsonList<T>(
    http.Response response,
    T Function(Map<String, dynamic> json) builder,
    String errorPrefix,
  ) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        '$errorPrefix with ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is! List) {
      throw const FormatException('Invalid response format');
    }

    return jsonBody
        .whereType<Map>()
        .map((item) => builder(Map<String, dynamic>.from(item)))
        .toList();
  }

  void dispose() {
    _http.close();
  }
}
