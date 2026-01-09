import 'package:aqlanstore/firebase_options.dart';
import 'package:aqlanstore/theme/app_colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('🔔 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 تهيئة Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 إعداد FCM
  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  // طلب الإذن + جلب التوكن
  await _initFCM();

  // 🟢 تهيئة Supabase
  await Supabase.initialize(
    url: 'https://nrjwzdkhwcqokwlmkzem.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yand6ZGtod2Nxb2t3bG1remVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MTkzMjYsImV4cCI6MjA3NjI5NTMyNn0.1c8usW_rodQEo0s2G8S5Ggc2NN8iOU0GO0Qd6yFAm8g',
  );


  runApp(const MyApp());
}

Future<void> _initFCM() async {
  final messaging = FirebaseMessaging.instance;

  // طلب الإذن (مهم جدًا للويب)
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ⚠️ ضع VAPID KEY الخاص بك هنا
  final token = await messaging.getToken(
    vapidKey: 'BDGITGdiQvRKEkWbWwoYcolzEz3GS9dWVYM1KrZgjLRAGQMkzYs8EQJGFf3j1B4XdmsFUcEqvgbYLKxN3sYPgVs',
  );

  debugPrint('🔥 FCM Token: $token');

  // 📌 هنا لاحقًا:
  // خزّن التوكن في Supabase (جدول admins مثلاً)
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bnaqlan Store',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
