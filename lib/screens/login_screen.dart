import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../utils/session_manager.dart';
import '../widgets/custom_text_field.dart';

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

  void logError(String title, Object error, StackTrace stack) {
    // مهم جدًا لـ iOS Web
    print('🔴 $title');
    print(error);
    print(stack);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;

    if (phone.isEmpty || pass.isEmpty) {
      _showError('الرجاء إدخال رقم الهاتف وكلمة المرور');
      return;
    }

    setState(() => _loading = true);

    try {
      print('LOGIN START');

      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('رقم الهاتف غير مسجل');
      }

      final doc = snapshot.docs.first;

      if (doc['password']?.toString() != pass) {
        throw Exception('كلمة المرور غير صحيحة');
      }

      final rawData = doc.data();
      if (rawData == null) {
        throw Exception('بيانات المستخدم غير موجودة');
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(rawData as Map);

      final user = User.fromJson({
        'customer_id': data['customer_id']?.toString() ?? '',
        'name': data['name']?.toString() ?? '',
        'phone': data['phone']?.toString() ?? '',
        'email': data['email']?.toString() ?? '',
        'profile_image': data['profile_image']?.toString() ?? '',
        'balance': double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0,
      });

      await SessionManager.saveUser(user);

      if (!mounted) return;

      print('LOGIN SUCCESS → GO HOME');

      // ✅ الحل الحاسم لمشكلة iOS Web
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e, stack) {
      logError('LOGIN ERRO101R', e, stack);
      _showError(e.toString().replaceFirst('Exception102: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _guestLogin() {
    try {
      print('GUEST LOGIN');
      print(ModalRoute.of(context));


      // لا نمرر أي object
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e, stack) {
      logError('GUEST LOGIN ERROR', e, stack);
      _showError('116خطأ أثناء الدخول كزائر');
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

                    CustomTextField(
                      controller: _phoneCtrl,
                      label: 'رقم الهاتف',
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 12),

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
                          icon: Icon(
                            _obscure
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
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
                          : const Text(
                        'دخول',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/register'),
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
