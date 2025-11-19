// lib/screens/register_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ======= ضع بيانات Supabase هنا أو استبدلها بمتغيرات بيئية =======
  static const String SUPABASE_PROJECT_URL = "https://nrjwzdkhwcqokwlmkzem.supabase.co";
  static const String SUPABASE_SERVICE_ROLE_KEY = "YOUR_SUPABASE_SERVICE_ROLE_KEY";
  static const String SUPABASE_PROFILES_BUCKET = "profiles"; // تأكد من وجوده

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (f != null) setState(() => _pickedImage = File(f.path));
    } catch (e) {
      // ignore
    }
  }

  String _generateOtp() {
    final rnd = (100000 + DateTime.now().millisecondsSinceEpoch % 900000);
    return rnd.toString();
  }

  Future<String> _uploadProfileImageToSupabase(File file, String destFilename) async {
    final uploadUrl = Uri.parse(
      "$SUPABASE_PROJECT_URL/storage/v1/object/$SUPABASE_PROFILES_BUCKET/$destFilename",
    );

    final bytes = await file.readAsBytes();

    final resp = await http.post(
      uploadUrl,
      headers: {
        "Content-Type": "application/octet-stream",
        "Authorization": "Bearer $SUPABASE_SERVICE_ROLE_KEY",
      },
      body: bytes,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return "$SUPABASE_PROJECT_URL/storage/v1/object/public/$SUPABASE_PROFILES_BUCKET/$destFilename";
    } else {
      debugPrint("Supabase upload failed: ${resp.statusCode} ${resp.body}");
      throw Exception("فشل رفع الصورة");
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    String profileImageUrl = "";

    try {
      if (_pickedImage != null) {
        final filename = "profile_${DateTime.now().millisecondsSinceEpoch}.jpg";
        profileImageUrl = await _uploadProfileImageToSupabase(_pickedImage!, filename);
      }

      final docRef = FirebaseFirestore.instance.collection('customers').doc();
      final otp = _generateOtp();
      final otpExpiresAt = DateTime.now().add(const Duration(minutes: 10));

      final data = {
        "name": name,
        "phone": phone,
        "email": email,
        "password": pass, // ملاحظة: كلمة المرور مخزنة كنص واضح، غير آمنة في الإنتاج
        "profile_image": profileImageUrl,
        "registration_dat": FieldValue.serverTimestamp(),
        "is_verified": false,
        "otp_code": otp,
        "otp_expires_at": Timestamp.fromDate(otpExpiresAt),
        "level": "customer",
      };

      await docRef.set(data);

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم التسجيل'),
          content: const Text('تم إنشاء الحساب بنجاح.\nيمكنك الآن تسجيل الدخول.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // العودة لواجهة تسجيل الدخول
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("register error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التسجيل: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validatePhone(String? v) {
    final s = v?.trim() ?? "";
    if (s.isEmpty) return 'أدخل رقم الجوال';
    if (s.length < 6) return 'رقم جوال غير صالح';
    return null;
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
    if (v.length < 6) return 'كلمة المرور قصيرة جداً';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _pickedImage != null ? FileImage(_pickedImage!) : null,
                    child: _pickedImage == null
                        ? const Icon(Icons.camera_alt_outlined, size: 30, color: Colors.black54)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني (اختياري)',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: _validatePass,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أعد كتابة كلمة المرور';
                    if (v != _passCtrl.text) return 'كلمتا المرور غير متطابقتين';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text('إنشاء حساب'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
