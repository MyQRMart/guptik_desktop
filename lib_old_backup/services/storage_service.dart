import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyUserId = 'user_id';
  static const String _keyPublicUrl = 'public_url';

  // Save all session data at once
  Future<void> saveSession({
    required String deviceId,
    required String userId,
    required String publicUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyPublicUrl, publicUrl);
  }

  // Clear data (Factory Reset)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Getters
  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getPublicUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPublicUrl);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyDeviceId) && prefs.containsKey(_keyPublicUrl);
  }
}