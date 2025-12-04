import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart'; // تأكد من المسار الصحيح

class ProfileScreen extends StatefulWidget {
  User user;

  ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _passwordCtrl;

  bool _loading = true;
  bool _saving = false;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _imageCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();

    // جلب بيانات المستخدم من Firestore عند فتح الشاشة
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('customers')
          .where('customer_id', isEqualTo: widget.user.id)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final fetchedUser = User.fromJson(snap.docs.first.data());
        setState(() {
          widget.user = fetchedUser;
          _nameCtrl.text = fetchedUser.name;
          _emailCtrl.text = fetchedUser.email;
          _phoneCtrl.text = fetchedUser.phone;
          _imageCtrl.text = fetchedUser.profileImage;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل جلب البيانات: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      _pickedImage = picked;
    });

    try {
      final bytes = await picked.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = '${ts}_${picked.name}';
      final supabase = Supabase.instance.client;

      // رفع الصورة إلى باكت 'products'
      await supabase.storage.from('products').uploadBinary(
        filename,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      // الحصول على رابط عام للصورة
      final publicUrl =
      supabase.storage.from('products').getPublicUrl(filename);

      setState(() {
        _imageCtrl.text = publicUrl;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم رفع الصورة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل رفع الصورة: $e')));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'profile_image': _imageCtrl.text.trim(),
    };

    // إذا تم إدخال كلمة مرور جديدة، أضفها إلى البيانات
    if (_passwordCtrl.text.trim().isNotEmpty) {
      data['password'] = _passwordCtrl.text.trim();
    }

    try {
      final col = FirebaseFirestore.instance.collection('customers');
      final snap = await col
          .where('customer_id', isEqualTo: widget.user.id)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        await col.doc(snap.docs.first.id).update(data);
      } else {
        data['customer_id'] = widget.user.id as String;
        await col.add(data);
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ البيانات')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _imageCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: _pickedImage != null
                  ? FileImage(File(_pickedImage!.path))
                  : (_imageCtrl.text.isNotEmpty
                  ? NetworkImage(_imageCtrl.text)
                  : const AssetImage('assets/images/default_avatar.png')
              as ImageProvider),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_camera),
              label: const Text('تغيير الصورة'),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration:
                    const InputDecoration(labelText: 'الهاتف'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                        labelText: 'كلمة المرور الجديدة'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.save),
                      label: Text(_saving
                          ? 'يتم الحفظ...'
                          : 'حفظ التغييرات'),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
