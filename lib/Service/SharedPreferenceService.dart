import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceService {
  static SharedPreferences? _prefs;

  static const String tokenKey = 'token';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // String
  static Future<void> setString(
      String key,
      String value,
      ) async {
    await _prefs?.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  // Bool
  static Future<void> setBool(
      String key,
      bool value,
      ) async {
    await _prefs?.setBool(key, value);
  }

  static bool getBool(String key) {
    return _prefs?.getBool(key) ?? false;
  }

  // Remove
  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  // Clear all
  static Future<void> clear() async {
    await _prefs?.clear();
  }

  // Token
  static Future<void> saveToken(String token) async {
    await _prefs?.setString(tokenKey, token);
  }

  static String? getToken() {
    return _prefs?.getString(tokenKey);
  }

  static Future<void> removeToken() async {
    await _prefs?.remove(tokenKey);
  }
}