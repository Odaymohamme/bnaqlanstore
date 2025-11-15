// lib/widgets/app_drawer.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/add_address_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/store_contact_screen.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/orders_screen.dart';

class AppDrawer extends StatefulWidget {
  final User user;
  const AppDrawer({Key? key, required this.user}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late User _user;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _pickAndUpload() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final uploadedFilename = await ApiService.uploadProfileImage(_user.id, file);

    if (uploadedFilename != null) {
      setState(() {
        _user = User(
          id: _user.id,
          name: _user.name,
          phone: _user.phone,
          email: _user.email,
          profileImage: uploadedFilename,
          balance: _user.balance,
        );
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل رفع الصورة')),
        );
      }
    }
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(_user.name),
                accountEmail: Text(_user.phone),
                currentAccountPicture: GestureDetector(
                  onTap: _pickAndUpload,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _user.profileImage.isNotEmpty
                            ? NetworkImage(
                          '${Constants.baseUrl}/uploads/${_user.profileImage}?v=${DateTime.now().millisecondsSinceEpoch}',
                        )
                            : null,
                        child: _user.profileImage.isEmpty
                            ? const Icon(Icons.person,
                            size: 40, color: Colors.white)
                            : null,
                        backgroundColor: Colors.grey[400],
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              _buildTile(Icons.home, 'الرئيسية', () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => HomeScreen(user: _user)),
                );
              }),
              _buildTile(Icons.person, 'ملفي الشخصي', () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(user: _user)),
                );
                // تحديث البيانات بعد العودة
                try {
                  final fresh = await ApiService.fetchProfile(_user.id);
                  if (mounted) setState(() => _user = fresh);
                } catch (_) {}
              }),
              _buildTile(Icons.history, 'الطلبات السابقة', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrdersScreen(user: _user)),
                );
              }),
              _buildTile(Icons.location_on_outlined, 'عناوين التوصيل', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user)),
                );
              }),
             /* _buildTile(Icons.info_outline, 'من نحن ', () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreContactScreen()),
                );
              }),*/
              const Spacer(),
              _buildTile(Icons.exit_to_app, 'تسجيل الخروج', () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }),

            ],
            ),
        );
    }
}