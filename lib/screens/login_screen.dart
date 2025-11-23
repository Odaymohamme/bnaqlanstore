import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/session_manager.dart';
import '../widgets/custom_text_field.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;

    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء ملء رقم الهاتف وكلمة المرور'), backgroundColor: Colors.red.shade400),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final User user = await ApiService.loginClient(phone, pass);

      // طباعة استجابة السيرفر للمساعدة في التصحيح
      try {
        print('login response user: ${user.toJson()}');
      } catch (_) {}

      // تحقق من أن الـ id صالح
      if (user.id <= 0) {
        throw Exception('استجابة غير صالحة من السيرفر: معرف المستخدم غير موجود');
      }

      // انتظر الحفظ وتحقق منه
      await SessionManager.saveUser(user);
      final savedId = await SessionManager.getUserId();
      print('Saved user id: $savedId');
      if (savedId <= 0) {
        throw Exception('فشل حفظ بيانات الجلسة.');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _guestLogin() async {
    final guestUser = User(
      id: 0,
      name: 'زائر',
      phone: '',
      email: '',
      profileImage: '',
      balance: 0,
    );

    // لا نحفظ الزائر تلقائياً. إذا أردت حفظه كجلسة، يمكنك فك السطر التالي
    // await SessionManager.saveUser(guestUser);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: guestUser)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/images/aqlann.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      'مرحبًا بك في بهارات بن عقلان ✨',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // حقل رقم الهاتف
                    CustomTextField(
                      controller: _phoneCtrl,
                      label: 'رقم الهاتف',
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 12),

                    // حقل كلمة المرور
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC68642),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Text('دخول', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('إنشاء حساب جديد'),
                    ),
                    TextButton(
                      onPressed: _guestLogin,
                      child: const Text('الدخول كزائر'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
