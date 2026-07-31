import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates and persists a stable device ID used to identify "this
/// installation" to the backend, since there is no login/auth yet.
/// Each device gets its own farms in the cloud database. Once real
/// authentication is added, this ID can be linked to a phone-number
/// based account instead of replaced.
class DeviceIdentityService {
  static const String _key = 'device_id_v1';
  static String? _cached;

  static Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
