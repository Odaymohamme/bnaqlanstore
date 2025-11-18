// lib/screens/profile_screen.dart
import 'dart:io';
<<<<<<< HEAD

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

=======
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
<<<<<<< HEAD
=======

>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
<<<<<<< HEAD

  File? _pickedImage;
  bool _saving = false;
  bool _loadingProfile = false;
=======
  File? _pickedImage;
  bool _saving = false;
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
<<<<<<< HEAD
    _nameController.text = _currentUser.name ?? '';
    _emailController.text = _currentUser.email ?? '';
=======
    _nameController.text = _currentUser.name;
    _emailController.text = _currentUser.email;
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
<<<<<<< HEAD
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (x != null) {
        setState(() => _pickedImage = File(x.path));
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await ApiService.updateProfile(
        customerId: _currentUser.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        profileImage: null, // empty => delete on server
        deleteImage: true,
      );

      if (ok) {
        final fresh = await ApiService.fetchProfile(_currentUser.id);
        if (fresh != null) {
          setState(() {
            _currentUser = fresh;
            _pickedImage = null;
          });
        }
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
    } catch (e) {
      debugPrint('deleteProfileImage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
=======
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
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
  }

  Future<void> _updateProfile() async {
    if (_saving) return;
    setState(() => _saving = true);

<<<<<<< HEAD
    try {
      final ok = await ApiService.updateProfile(
        customerId: _currentUser.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        profileImage: _pickedImage,
      );

      if (ok) {
        // get fresh profile from server to reflect new image/url
        final fresh = await ApiService.fetchProfile(_currentUser.id);
        if (fresh != null) {
          setState(() {
            _currentUser = fresh;
            _pickedImage = null;
            _passwordController.clear();
          });
        }
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
    } catch (e) {
      debugPrint('updateProfile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Returns an ImageProvider for avatar: priority
  /// 1) picked image (local)
  /// 2) server image (profileImage path)
  /// 3) null => show placeholder
  ImageProvider<Object>? _buildAvatarImageProvider() {
    if (_pickedImage != null) {
      return FileImage(_pickedImage!);
    }

    final serverImage = (_currentUser.profileImage ?? '').trim();
    if (serverImage.isNotEmpty) {
      // If profileImage stored as path like "uploads/xxx.jpg", build full URL
      String url;
      if (serverImage.startsWith('http')) {
        url = serverImage;
      } else {
        // ensure Constants.baseUrl doesn't end with slash
        final base = Constants.baseUrl.endsWith('/') ? Constants.baseUrl.substring(0, Constants.baseUrl.length - 1) : Constants.baseUrl;
        url = '$base/uploads/$serverImage?v=${DateTime.now().millisecondsSinceEpoch}';
      }
      return NetworkImage(url);
    }

    return null;
=======
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
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final avatarProvider = _buildAvatarImageProvider();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
        centerTitle: true,
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('اختر صورة'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _deleteProfileImage,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('حذف الصورة', style: TextStyle(color: Colors.red)),
                ),
              ],
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
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور (اختياري)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _updateProfile,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
=======
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
>>>>>>> b2b349f86658c0185fdfa973014029ace78b4836
