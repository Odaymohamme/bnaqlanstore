// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  File? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController.text = _currentUser.name;
    _emailController.text = _currentUser.email;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _pickedImage = File(x.path));
  }
  Future<void> _deleteProfileImage() async {
    setState(() => _saving = true);

    final ok = await ApiService.updateProfile(
      customerId: _currentUser.id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      profileImage: null, // نفرغ الصورة
      deleteImage: true, // نرسل فلاغ لحذفها
    );

    if (ok) {
      final fresh = await ApiService.fetchProfile(_currentUser.id);
      setState(() {
        _currentUser = fresh;
        _pickedImage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حذف الصورة بنجاح')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل حذف الصورة')),
        );
      }
    }

    if (mounted) setState(() => _saving=false);
  }

  Future<void> _updateProfile() async {
    if (_saving) return;
    setState(() => _saving = true);

    final ok = await ApiService.updateProfile(
      customerId: _currentUser.id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      profileImage: _pickedImage,
    );

    if (ok) {
      // اجلب نسخة محدثة من السيرفر لعرض الصورة الجديدة فورًا
      final fresh = await ApiService.fetchProfile(_currentUser.id);
      setState(() {
        _currentUser = fresh;
        _pickedImage = null;
        _passwordController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم التحديث بنجاح')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل التحديث')),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;

    if (_pickedImage != null) {
      // صورة مختارة من الجهاز (مؤقتة)
      imageProvider = FileImage(_pickedImage!);
    } else if (_currentUser.profileImage.isNotEmpty) {
      // صورة من السيرفر
      imageProvider = NetworkImage(
        '${Constants.baseUrl}/uploads/${_currentUser.profileImage}?v=${DateTime.now().millisecondsSinceEpoch}',
      );
    } else {
      // لا توجد صورة → نتركها فارغة ونظهر الأيقونة
      imageProvider = null;
    }

    return Scaffold(
        appBar: AppBar(title: const Text('ملفي الشخصي'), centerTitle: true),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: imageProvider,
                    backgroundColor: Colors.grey[400],
                    child: imageProvider == null
                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration:
                  const InputDecoration(labelText: 'كلمة المرور (اختياري)'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _updateProfile,
                    icon: _saving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.save),
                    label: const Text('حفظ التعديلات'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _saving ? null : _deleteProfileImage,
                      icon: const Icon(Icons.delete),
                      label: const Text('حذف الصورة'),
                      ),
                ),
              ],
            ),
            ),
        );

    }
}