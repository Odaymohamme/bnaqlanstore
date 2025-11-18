import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تحميل متغيرات البيئة من ملف .env (محلياً)
  await dotenv.load(fileName: ".env");


  // تهيئة Firebase
  await Firebase.initializeApp();

  // تهيئة Supabase باستخدام المتغيرات من .env
<<<<<<< HEAD
  final supabaseUrl = 'https://nrjwzdkhwcqokwlmkzem.supabase.co';
  final supabaseAnonKey ='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yand6ZGtod2Nxb2t3bG1remVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MTkzMjYsImV4cCI6MjA3NjI5NTMyNn0.1c8usW_rodQEo0s2G8S5Ggc2NN8iOU0GO0Qd6yFAm8g';
=======
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836

  if (supabaseUrl == null || supabaseAnonKey == null) {
    // أثناء التطوير نفعل هذا التحذير؛ في بيئة الإنتاج تأكد من تمرير المتغيرات
    throw Exception('Supabase URL or ANON_KEY not found. Create a .env file from .env.example');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // بعد تهيئة كل شيء نشغّل التطبيق
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}