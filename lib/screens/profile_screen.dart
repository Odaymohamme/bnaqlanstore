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
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController.text = _currentUser.name ?? '';
    _emailController.text = _currentUser.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
  }

  Future<void> _updateProfile() async {
    if (_saving) return;
    setState(() => _saving = true);

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
  }

  @override
  Widget build(BuildContext context) {
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
