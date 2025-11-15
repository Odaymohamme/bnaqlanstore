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
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

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