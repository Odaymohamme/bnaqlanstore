import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/add_address_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/store_contact_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _listenUserUpdates();
  }

  /// الاستماع للتحديثات في Firestore لتحديث بيانات المستخدم تلقائيًا
  void _listenUserUpdates() {
    FirebaseFirestore.instance
        .collection('customers')
        .where('customer_id', isEqualTo: _user.id)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final freshUser = User.fromJson(snapshot.docs.first.data());
        if (mounted) {
          setState(() => _user = freshUser);
        }
      }
    });
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
            currentAccountPicture: CircleAvatar(
              radius: 40,
              backgroundImage: _user.profileImage.isNotEmpty
                  ? NetworkImage(_user.profileImage) // استخدم الرابط الكامل المخزن في Supabase
                  : null,
              child: _user.profileImage.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
              backgroundColor: Colors.grey[400],
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
            // تحديث البيانات بعد العودة من الملف الشخصي
            try {
              final snap = await FirebaseFirestore.instance
                  .collection('customers')
                  .where('customer_id', isEqualTo: _user.id)
                  .limit(1)
                  .get();

              if (snap.docs.isNotEmpty && mounted) {
                setState(() => _user = User.fromJson(snap.docs.first.data()));
              }
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
              MaterialPageRoute(
                  builder: (_) => AddAddressScreen(user: _user)),
            );
          }),
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
