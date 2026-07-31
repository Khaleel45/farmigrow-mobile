import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/api_service.dart';

/// Local-first pond storage with background cloud sync.
/// Mirrors the pattern used in FarmStorage.
class PondStorage {
  static const String _key = 'user_ponds_v1';

  static Future<List<AquaPond>> getUserPonds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null || data.isEmpty) return [];
      final List<dynamic> list = jsonDecode(data);
      return list.map((j) => AquaPond.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _writeLocal(List<AquaPond> ponds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ponds.map((p) => p.toJson()).toList()));
  }

  static Future<bool> savePond(AquaPond pond) async {
    try {
      final ponds = await getUserPonds();
      final idx = ponds.indexWhere((p) => p.id == pond.id);
      if (idx >= 0) {
        ponds[idx] = pond;
      } else {
        ponds.add(pond);
      }
      await _writeLocal(ponds);
      // Background sync to cloud
      ApiService.syncPond(pond);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePond(String id) async {
    try {
      final ponds = await getUserPonds();
      ponds.removeWhere((p) => p.id == id);
      await _writeLocal(ponds);
      ApiService.deletePond(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<AquaPond>> syncFromCloud() async {
    final cloudPonds = await ApiService.getPonds();
    if (cloudPonds.isEmpty) return getUserPonds();
    final localPonds = await getUserPonds();
    final merged = <String, AquaPond>{};
    for (final p in localPonds) merged[p.id] = p;
    for (final p in cloudPonds) merged[p.id] = p;
    final result = merged.values.toList();
    await _writeLocal(result);
    return result;
  }
}
