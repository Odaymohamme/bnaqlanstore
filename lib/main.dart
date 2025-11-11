import 'package:aqlanstore/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ ضروري قبل أي await
  await Firebase.initializeApp(); // ✅ تهيئة الفايربيس قبل تشغيل التطبيق
  runApp(const MyApp());
  // تهيئة Supabase
  await Supabase.initialize(
    url: 'https://nrjwzdkhwcqokwlmkzem.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yand6ZGtod2Nxb2t3bG1remVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MTkzMjYsImV4cCI6MjA3NjI5NTMyNn0.1c8usW_rodQEo0s2G8S5Ggc2NN8iOU0GO0Qd6yFAm8g',
  );
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
