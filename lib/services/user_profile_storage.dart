import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farmigrow_ai/models/user_profile.dart';
import 'package:farmigrow_ai/services/api_service.dart';

export 'package:farmigrow_ai/models/user_profile.dart';

/// Local-first profile storage with background cloud sync, mirroring
/// the pattern used in FarmStorage.
class UserProfileStorage {
  static const String _key = 'user_profile_v1';

  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return UserProfile.defaultProfile();
    try {
      return UserProfile.fromJson(jsonDecode(data));
    } catch (_) {
      return UserProfile.defaultProfile();
    }
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));

    // Fire-and-forget cloud sync
    ApiService.syncProfile(profile);
  }

  /// Pulls the profile from the cloud (useful after reinstalling the
  /// app on the same device, or if a future login system links this
  /// device to an existing account). Falls back to local data if the
  /// backend is unreachable.
  static Future<UserProfile> syncFromCloud() async {
    final cloudProfile = await ApiService.getProfile();
    if (cloudProfile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(cloudProfile.toJson()));
      return cloudProfile;
    }
    return getProfile();
  }
}
