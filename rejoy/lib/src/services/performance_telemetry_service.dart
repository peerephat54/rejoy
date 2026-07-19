import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.elapsedMs,
    required this.createdAt,
    required this.detail,
  });

  final String name;
  final int elapsedMs;
  final DateTime createdAt;
  final String detail;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'elapsedMs': elapsedMs,
      'createdAt': createdAt.toIso8601String(),
      'detail': detail,
    };
  }

  factory TelemetryEvent.fromJson(Map<String, dynamic> json) {
    return TelemetryEvent(
      name: json['name']?.toString() ?? 'unknown',
      elapsedMs: int.tryParse(json['elapsedMs']?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      detail: json['detail']?.toString() ?? '',
    );
  }
}

class PerformanceTelemetryService {
  const PerformanceTelemetryService();

  static const _storageKey = 'rejoy_performance_telemetry_v1';

  Future<T> measure<T>({
    required String name,
    required Future<T> Function() action,
    String detail = '',
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      await record(
        name: name,
        elapsedMs: stopwatch.elapsedMilliseconds,
        detail: detail,
      );
    }
  }

  Future<T> measureSync<T>({
    required String name,
    required T Function() action,
    String detail = '',
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return action();
    } finally {
      stopwatch.stop();
      await record(
        name: name,
        elapsedMs: stopwatch.elapsedMilliseconds,
        detail: detail,
      );
    }
  }

  Future<void> record({
    required String name,
    required int elapsedMs,
    String detail = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await load();
    events.insert(
      0,
      TelemetryEvent(
        name: name,
        elapsedMs: elapsedMs,
        createdAt: DateTime.now(),
        detail: detail,
      ),
    );
    if (events.length > 60) {
      events.removeRange(60, events.length);
    }
    await prefs.setString(
      _storageKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }

  Future<List<TelemetryEvent>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => TelemetryEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
