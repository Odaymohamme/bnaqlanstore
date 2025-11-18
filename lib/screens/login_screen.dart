// lib/screens/login_screen.dart
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
  final _formKey = GlobalKey<FormState>();
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
    // Validate form first
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      final phone = _phoneCtrl.text.trim();
      final pass = _passCtrl.text;

      // استدعاء الـ API الحالي لديك
      final User user = await ApiService.loginClient(phone, pass);

      // حفظ الجلسة (إذا لديك SessionManager)
      await SessionManager.saveUser(user);

      // نجح: انتقل للشاشة الرئيسية (استبدل الstack)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      // عرض رسالة مفهومة للمستخدم
      final msg = e?.toString() ?? 'حدث خطأ أثناء تسجيل الدخول';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, textAlign: TextAlign.right)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // اختياري: دخول كزائر
  void _guestLogin() {
    final guestUser = User(
      id: 0,
      name: 'زائر',
      phone: '',
      email: '',
      profileImage: '',
      balance: 0,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(user: guestUser)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'مرحبًا بك في بهارات بن عقلان ✨',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // رقم الهاتف
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return 'أدخل رقم الجوال';
                    if (val.length < 6) return 'رقم غير صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // كلمة المرور
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
                    if (v.length < 4) return 'كلمة المرور قصيرة';
                    return null;
                  },
                  onFieldSubmitted: (_) => _login(),
                ),

                const SizedBox(height: 12),

                // زر تسجيل الدخول
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Text('دخول', style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 8),

                // نسيت كلمة المرور و تسجيل
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        // TODO: implement forgot password flow
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('ميزة استرجاع كلمة المرور غير مفعلة بعد')));
                      },
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text('إنشاء حساب جديد'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // دخول كزائر
                TextButton(
                  onPressed: _guestLogin,
                  child: const Text('الدخول كزائر'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
