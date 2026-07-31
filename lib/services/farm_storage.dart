import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/api_service.dart';

/// Local-first storage with background cloud sync.
///
/// - Reads always come from local SharedPreferences (instant, works
///   offline).
/// - Writes save locally first (so the UI never waits on network), then
///   fire a background sync to the Railway backend. If the network call
///   fails, the local copy is still correct and a future call to
///   [syncFromCloud] or another save will retry.
/// - [syncFromCloud] pulls the latest farms from the backend and merges
///   them into local storage — used on app startup so a reinstall or a
///   second device picks up existing data.
class FarmStorage {
  static const String _key = 'user_farms_v3';

  static Future<List<Farm>> getUserFarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null || data.isEmpty) return [];
      final List<dynamic> list = jsonDecode(data);
      return list.map((j) => Farm.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      print('Error loading farms: $e');
      return [];
    }
  }

  static Future<void> _writeLocal(List<Farm> farms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(farms.map((f) => f.toJson()).toList()));
  }

  /// Saves locally immediately, then syncs to the cloud in the
  /// background. Returns true as soon as the local save succeeds —
  /// callers don't need to wait for the network.
  static Future<bool> saveFarm(Farm farm) async {
    try {
      final farms = await getUserFarms();
      final existingIndex = farms.indexWhere((f) => f.id == farm.id);
      if (existingIndex >= 0) {
        farms[existingIndex] = farm;
      } else {
        farms.add(farm);
      }
      await _writeLocal(farms);
      print('Farm saved locally: ${farm.name}, total: ${farms.length}');

      // Fire-and-forget cloud sync — don't block the UI on network.
      ApiService.syncFarm(farm).then((success) {
        print(success
            ? 'Farm synced to cloud: ${farm.name}'
            : 'Cloud sync failed for ${farm.name} (will retry on next app open)');
      });

      return true;
    } catch (e) {
      print('Error saving farm: $e');
      return false;
    }
  }

  static Future<bool> deleteFarm(String id) async {
    try {
      final farms = await getUserFarms();
      farms.removeWhere((f) => f.id == id);
      await _writeLocal(farms);

      ApiService.deleteFarm(id); // fire-and-forget

      return true;
    } catch (e) {
      print('Error deleting farm: $e');
      return false;
    }
  }

  static Future<int> getFarmCount() async {
    final farms = await getUserFarms();
    return farms.length;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Pulls farms from the cloud and merges them into local storage.
  /// Cloud data wins on conflict (it may contain satellite-updated
  /// fields that are newer than what's on this device). Call this on
  /// app startup and whenever the user pulls-to-refresh.
  ///
  /// Returns the merged list, or the unchanged local list if the
  /// backend is unreachable (e.g. no internet).
  static Future<List<Farm>> syncFromCloud() async {
    final cloudFarms = await ApiService.getFarms();
    if (cloudFarms.isEmpty) {
      // Either no farms in the cloud yet, or backend unreachable.
      // Either way, local data is untouched.
      return getUserFarms();
    }

    final localFarms = await getUserFarms();
    final merged = <String, Farm>{};
    for (final f in localFarms) {
      merged[f.id] = f;
    }
    for (final f in cloudFarms) {
      merged[f.id] = f; // cloud overwrites local on matching ID
    }

    final result = merged.values.toList();
    await _writeLocal(result);
    return result;
  }
}
