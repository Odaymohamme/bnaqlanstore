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
// --- استبدل getUser و getUserId بالنسخة الأكثر تحملاً التالية ---

  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyUserJson);
    if (s == null) return null;
    try {
      final decoded = jsonDecode(s);
      Map<String, dynamic> map;
      if (decoded is Map) {
        map = decoded.map((k, v) => MapEntry(k.toString(), v));
      } else {
        // غير متوقع: يتم إعادة القيمة كقائمة أو نص، نمرّ بخطوة آمنة
        return null;
      }
      return User.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      // سطّر الخطأ للاطلاع لاحقاً
      print('SessionManager.getUser decode error: $e');
      await prefs.remove(_keyUserJson);
      return null;
    }
  }

  static Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final dynamic raw = prefs.get(_keyUserId);
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    // Fall-back generic
    try {
      return int.parse(raw.toString());
    } catch (_) {
      return 0;
    }
  }
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserJson);
    await prefs.remove(_keyUserId);
  }
}
