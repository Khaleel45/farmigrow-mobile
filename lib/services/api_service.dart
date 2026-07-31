import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/device_identity_service.dart';
import 'package:farmigrow_ai/models/user_profile.dart';

/// Talks to the FarmiGrow AI backend (FastAPI on Railway). Every call is
/// scoped to this device's ID since there's no login yet — each phone
/// installation has its own cloud-synced farms.
///
/// IMPORTANT: update [baseUrl] to your deployed Railway URL once it's
/// live, e.g. https://farmigrow-backend.up.railway.app
class ApiService {
  static const String baseUrl = 'https://farmigrow-backend-production-54c2.up.railway.app';

  static Map<String, String> get _headers => {'Content-Type': 'application/json'};

  static const Duration _timeout = Duration(seconds: 12);

  // ─── FARMS ───────────────────────────────────────────

  static Future<List<Farm>> getFarms() async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .get(Uri.parse('$baseUrl/farms/?device_id=$deviceId'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => Farm.fromJson(Map<String, dynamic>.from(j))).toList();
      }
    } catch (e) {
      // Offline or backend unreachable — caller falls back to local storage
    }
    return [];
  }

  /// Creates or updates a farm in the cloud. Safe to call repeatedly with
  /// the same farm.id — the backend upserts rather than duplicating.
  static Future<bool> syncFarm(Farm farm) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .post(
            Uri.parse('$baseUrl/farms/?device_id=$deviceId'),
            headers: _headers,
            body: jsonEncode(farm.toJson()),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteFarm(String farmId) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .delete(Uri.parse('$baseUrl/farms/$farmId?device_id=$deviceId'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── PROFILE ─────────────────────────────────────────

  static Future<UserProfile?> getProfile() async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .get(Uri.parse('$baseUrl/profile/?device_id=$deviceId'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      // ignore — caller falls back to local
    }
    return null;
  }

  static Future<bool> syncProfile(UserProfile profile) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .post(
            Uri.parse('$baseUrl/profile/?device_id=$deviceId'),
            headers: _headers,
            body: jsonEncode(profile.toJson()),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── PONDS ───────────────────────────────────────────

  static Future<List<AquaPond>> getPonds() async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .get(Uri.parse('$baseUrl/ponds/?device_id=$deviceId'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((j) => AquaPond.fromJson(Map<String, dynamic>.from(j))).toList();
      }
    } catch (e) {
      // ignore — caller falls back to local
    }
    return [];
  }

  static Future<bool> syncPond(AquaPond pond) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .post(
            Uri.parse('$baseUrl/ponds/?device_id=$deviceId'),
            headers: _headers,
            body: jsonEncode(pond.toJson()),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deletePond(String pondId) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .delete(Uri.parse('$baseUrl/ponds/$pondId?device_id=$deviceId'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> scanPond(String pondId) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .post(
            Uri.parse('$baseUrl/ponds/scan/$pondId?device_id=$deviceId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, ...body};
      return {'success': false, 'error': body['detail'] ?? 'Scan failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Quick reachability check used by the UI to show an online/offline
  /// indicator without blocking on a full sync.
  static Future<bool> isBackendReachable() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── SATELLITE ───────────────────────────────────────

  /// Checks whether the backend has Sentinel Hub credentials
  /// configured at all (i.e. whether a Copernicus account has been
  /// set up), without triggering an actual scan.
  static Future<Map<String, dynamic>?> getSatelliteStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/satellite/status'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Triggers a real Sentinel-2/Sentinel-1 scan for one farm. This can
  /// take 5-20 seconds since it's a live call to Copernicus, so it
  /// uses a longer timeout than other requests. Returns a result map
  /// with the new NDVI/NDWI readings on success, or a map containing
  /// an "error" key with a human-readable reason on failure (e.g. "no
  /// boundary drawn" or "Sentinel not configured yet").
  static Future<Map<String, dynamic>> scanFarm(String farmId) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .post(
            Uri.parse('$baseUrl/satellite/scan/$farmId?device_id=$deviceId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 45));

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        // After a successful scan the backend has updated the farm in the
        // database. Pull the fresh farm list so the app reflects the new
        // health score, water stress, etc. immediately without the user
        // needing to close and reopen.
        return {'success': true, ...body};
      }

      // Surface the actual error from the backend instead of a generic
      // "check internet" message — this makes debugging much easier.
      final detail = body['detail']?.toString() ?? 'Unknown error (${res.statusCode})';
      return {'success': false, 'error': detail};
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Scan timed out (45s). Sentinel Hub is slow to respond — try again in a moment.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString().replaceAll('Exception: ', '')}'
      };
    }
  }

  /// Test scan using FAKE data — bypasses Sentinel Hub entirely.
  /// Use this to verify the full data pipeline works (backend →
  /// database → app → UI refresh) before debugging Sentinel separately.
  static Future<Map<String, dynamic>> testScan(String farmId) async {
    try {
      final deviceId = await DeviceIdentityService.getDeviceId();
      final res = await http
          .post(
            Uri.parse('$baseUrl/satellite/test-scan/$farmId?device_id=$deviceId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, ...body};
      return {'success': false, 'error': body['detail'] ?? 'Test scan failed (${res.statusCode})'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
