import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores a rolling 30-day history of scan results per farm.
/// Used to draw trend charts on the dashboard.
class ScanRecord {
  final String date;
  final int healthScore;
  final int pestRiskPercent;
  final String waterStressLevel;
  final String diseaseRiskLevel;

  ScanRecord({
    required this.date,
    required this.healthScore,
    required this.pestRiskPercent,
    required this.waterStressLevel,
    required this.diseaseRiskLevel,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'healthScore': healthScore,
    'pestRiskPercent': pestRiskPercent,
    'waterStressLevel': waterStressLevel,
    'diseaseRiskLevel': diseaseRiskLevel,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> j) => ScanRecord(
    date: j['date'] ?? '',
    healthScore: (j['healthScore'] as num?)?.toInt() ?? 70,
    pestRiskPercent: (j['pestRiskPercent'] as num?)?.toInt() ?? 0,
    waterStressLevel: j['waterStressLevel'] ?? 'Low',
    diseaseRiskLevel: j['diseaseRiskLevel'] ?? 'Low',
  );
}

class ScanHistoryStorage {
  static const int _maxRecords = 30; // Keep 30 days

  static String _key(String farmId) => 'scan_history_$farmId';

  static Future<List<ScanRecord>> getHistory(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key(farmId));
    if (data == null) return [];
    final List list = jsonDecode(data);
    return list.map((j) => ScanRecord.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  static Future<void> addRecord(String farmId, ScanRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory(farmId);

    // Remove duplicate for same date
    history.removeWhere((r) => r.date == record.date);
    history.add(record);

    // Keep only last 30 records sorted by date
    history.sort((a, b) => a.date.compareTo(b.date));
    final trimmed = history.length > _maxRecords
        ? history.sublist(history.length - _maxRecords)
        : history;

    await prefs.setString(_key(farmId), jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }

  static Future<void> clearHistory(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(farmId));
  }
}
