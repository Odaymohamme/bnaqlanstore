// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../utils/session_manager.dart';
import '../models/user.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // شاشة انتظار قصيرة لعرض الشعار
    await Future.delayed(const Duration(seconds: 2));

    // استرجاع المستخدم من الجلسة
    final User? user = await SessionManager.getUser();

    if (!mounted) return;

    // إذا كان هناك مستخدم، اذهب مباشرة إلى HomeScreen
    if (user != null && user.id > 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } else {
      // إذا لم يوجد مستخدم، افتح شاشة تسجيل الدخول
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
