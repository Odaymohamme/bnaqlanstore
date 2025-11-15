import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class SessionManager {
  /// حفظ بيانات المستخدم بعد تسجيل الدخول
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setDouble('user_balance', user.balance);
    await prefs.setString('user_phone', user.phone);
    await prefs.setString('user_profileImage', user.profileImage);
  }

  /// استرجاع بيانات المستخدم
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');
    final balance = prefs.getDouble('user_balance');
    final phone = prefs.getString('user_phone');
    final profileImage = prefs.getString('user_profileImage');

    if (id != null && name != null && email != null && balance != null && phone != null && profileImage != null) {
      return User(
        id: id,
        name: name,
        email: email,
        balance: balance,
        phone: phone,
        profileImage: profileImage,
      );
    }
    return null;
  }

  /// حذف بيانات المستخدم (تسجيل الخروج)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    }
}