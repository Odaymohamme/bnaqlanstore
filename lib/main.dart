import 'package:aqlanstore/firebase_options.dart';
import 'package:aqlanstore/screens/home_screen.dart';
import 'package:aqlanstore/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_web_plugins/url_strategy.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تحميل env فقط في غير الويب
  if (!kIsWeb) {
    usePathUrlStrategy();
    await dotenv.load(fileName: ".env");
  }

  // Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  // Supabase
  final supabaseUrl = kIsWeb
      ? const String.fromEnvironment('SUPABASE_URL')
      : dotenv.env['SUPABASE_URL'];

  final supabaseAnonKey = kIsWeb
      ? const String.fromEnvironment('SUPABASE_ANON_KEY')
      : dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Supabase credentials not found');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

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

      // مهم جدًا للـ Web + iOS
      initialRoute: '/',

      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(user: null),
      },
    );

  }
}
