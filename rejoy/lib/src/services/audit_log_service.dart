import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuditEvent {
  const AuditEvent({
    required this.type,
    required this.timestamp,
    required this.riskLevel,
    required this.detail,
  });

  final String type;
  final DateTime timestamp;
  final String riskLevel;
  final String detail;

  Map<String, dynamic> toJson() => {
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'riskLevel': riskLevel,
    'detail': detail,
  };

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      type: json['type']?.toString() ?? 'UNKNOWN',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      riskLevel: json['riskLevel']?.toString() ?? 'green',
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class AuditLogService {
  const AuditLogService();

  static const _key = 'rejoy_anonymous_audit_events_v1';
  static const _maxEvents = 80;

  Future<void> record({
    required String type,
    String riskLevel = 'green',
    String detail = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await load();
    events.insert(
      0,
      AuditEvent(
        type: type,
        timestamp: DateTime.now(),
        riskLevel: riskLevel,
        detail: detail,
      ),
    );
    final trimmed = events.take(_maxEvents).map((event) => event.toJson());
    await prefs.setString(_key, jsonEncode(trimmed.toList()));
  }

  Future<List<AuditEvent>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => AuditEvent.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
