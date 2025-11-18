<<<<<<< HEAD
// lib/screens/login_screen.dart
=======
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/session_manager.dart';
import '../widgets/custom_text_field.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
<<<<<<< HEAD
  const LoginScreen({Key? key}) : super(key: key);

=======
  const LoginScreen({super.key});
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
<<<<<<< HEAD
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
=======
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      User user = await ApiService.loginClient(
        _phoneCtrl.text.trim(),
        _passCtrl.text.trim(),
      );

      // ✅ حفظ بيانات المستخدم كاملة
      await SessionManager.saveUser(user);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      if (mounted && _error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!), backgroundColor: Colors.red.shade400),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    'assets/images/aqlann.jpg', // تأكد أن الصورة موجودة
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'مرحبًا بك في بهارات بن عقلان ✨',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        controller: _phoneCtrl,
                        label: 'رقم الهاتف',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _passCtrl,
                        label: 'كلمة المرور',
                        obscure: true,
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
                            : const Text(
                          'دخول',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: const Text('إنشاء حساب جديد'),
                      ),
                      TextButton(
                        onPressed: () {
                          final guestUser = User(
                            id: 0,
                            name: "زائر",
                            email: "",
                            phone: "",
                            profileImage: "",
                            balance: 0.0,
                          );

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => HomeScreen(user: guestUser)),
                          );
                        },
                        child: const Text("الدخول كزائر"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
        );
    }
}
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
