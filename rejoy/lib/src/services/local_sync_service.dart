import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'rejoy_api_client.dart';

class LocalSyncService {
  const LocalSyncService();

  static const _pendingOpsKey = 'rejoy_pending_sync_ops_v1';
  static const _diaryPrefix = 'rejoy_diary_draft_v1';
  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveDiaryDraft({
    required String userId,
    required String note,
    DateTime? date,
  }) async {
    await _secureStorage.write(
      key: _diaryKey(userId, date ?? DateTime.now()),
      value: note,
    );
  }

  Future<String?> loadDiaryDraft({
    required String userId,
    DateTime? date,
  }) async {
    return _secureStorage.read(key: _diaryKey(userId, date ?? DateTime.now()));
  }

  Future<void> enqueueReportCreate({
    required String userId,
    required Map<String, dynamic> payload,
  }) {
    return _enqueue({
      'id': _newId('report_create'),
      'type': 'report_create',
      'userId': userId,
      'payload': payload,
    });
  }

  Future<void> enqueueReportUpdate({
    required String reportId,
    required Map<String, dynamic> payload,
  }) {
    return _enqueue({
      'id': _newId('report_update'),
      'type': 'report_update',
      'reportId': reportId,
      'payload': payload,
    });
  }

  Future<void> enqueueQuestDayFinish({
    required String userId,
    required Map<String, dynamic> payload,
  }) {
    return _enqueue({
      'id': _newId('quest_day_finish'),
      'type': 'quest_day_finish',
      'userId': userId,
      'payload': payload,
    });
  }

  Future<int> pendingCount() async {
    final ops = await _readOps();
    return ops.length;
  }

  Future<int> flush(ReJoyApiClient client) async {
    final ops = await _readOps();
    if (ops.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var synced = 0;

    for (final op in ops) {
      try {
        await _syncOne(client, op);
        synced += 1;
      } catch (_) {
        remaining.add(op);
      }
    }

    await _writeOps(remaining);
    return synced;
  }

  Future<void> _syncOne(ReJoyApiClient client, Map<String, dynamic> op) async {
    final payload = Map<String, dynamic>.from(op['payload'] as Map);
    switch (op['type']?.toString()) {
      case 'report_create':
        await client.createReportForUser(
          userId: op['userId'].toString(),
          dailyMood: payload['dailyMood']?.toString(),
          diaryNote: payload['diaryNote']?.toString(),
          cbtCompletionRate: payload['cbtCompletionRate']?.toString(),
          unlockedAnimalToday: payload['unlockedAnimalToday']?.toString(),
          isRestDay: payload['isRestDay'] as bool?,
          isSosTriggered: payload['isSosTriggered'] as bool?,
          date: _date(payload['date']),
        );
        return;
      case 'report_update':
        await client.updateReport(
          reportId: op['reportId'].toString(),
          dailyMood: payload['dailyMood']?.toString(),
          diaryNote: payload['diaryNote']?.toString(),
          cbtCompletionRate: payload['cbtCompletionRate']?.toString(),
          unlockedAnimalToday: payload['unlockedAnimalToday']?.toString(),
          isRestDay: payload['isRestDay'] as bool?,
          isSosTriggered: payload['isSosTriggered'] as bool?,
          date: _date(payload['date']),
        );
        return;
      case 'quest_day_finish':
        await client.finishQuestDayForUser(
          userId: op['userId'].toString(),
          selectedQuests: _stringList(payload['selectedQuests']),
          completedQuests: _stringList(payload['completedQuests']),
          completionRate: payload['completionRate']?.toString(),
          energyModeSelected: payload['energyModeSelected']?.toString(),
          isRestDay: payload['isRestDay'] as bool?,
        );
        return;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> op) async {
    final ops = await _readOps();
    ops.add(op);
    await _writeOps(ops);
  }

  Future<List<Map<String, dynamic>>> _readOps() async {
    final raw = await _secureStorage.read(key: _pendingOpsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _writeOps(List<Map<String, dynamic>> ops) async {
    if (ops.isEmpty) {
      await _secureStorage.delete(key: _pendingOpsKey);
      return;
    }
    await _secureStorage.write(key: _pendingOpsKey, value: jsonEncode(ops));
  }

  static String _diaryKey(String userId, DateTime date) {
    return '${_diaryPrefix}_${userId}_${_dayKey(date)}';
  }

  static String _dayKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String _newId(String type) {
    return '${type}_${DateTime.now().microsecondsSinceEpoch}';
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return <String>[];
    return value.map((item) => item.toString()).toList();
  }
}
