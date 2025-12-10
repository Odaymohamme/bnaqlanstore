import 'package:aqlanstore/services/connection_service.dart';
import 'package:aqlanstore/theme/app_colors.dart';
import 'package:aqlanstore/widgets/network_banner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تحميل متغيرات البيئة
  await dotenv.load(fileName: ".env");

  // تهيئة Firebase
  await Firebase.initializeApp();

  // تهيئة Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Supabase URL or ANON_KEY not found. Create a .env file from .env.example');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  ConnectionService.initialize();

  runApp(const MyApp());
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

      builder: (context, child) {
        return Column(
          children: [
            const NetworkDialog(), // ✅ شريط الإنترنت
            Expanded(child: child!),
          ],
        );
      },
    );
  }

}