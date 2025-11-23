// lib/utils/session_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class SessionManager {
  static const _keyUserJson = 'user_json';
  static const _keyUserId = 'user_id';

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserJson, jsonEncode(user.toJson()));
    await prefs.setInt(_keyUserId, user.id);
  }

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyUserJson);
    if (s == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(s));
      return User.fromJson(map);
    } catch (e) {
      await prefs.remove(_keyUserJson);
      return null;
    }
  }

  static Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId) ?? 0;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserJson);
    await prefs.remove(_keyUserId);
  }
}
