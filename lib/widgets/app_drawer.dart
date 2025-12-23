import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/add_address_screen.dart';
import '../screens/offers_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/orders_screen.dart';
import '../models/user.dart';

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

  void _listenUserUpdates() {
    FirebaseFirestore.instance
        .collection('customers')
        .where('customer_id', isEqualTo: _user.id)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _user = User.fromJson(snapshot.docs.first.data());
        });
      }
    });
  }

  Widget _buildTile(
      BuildContext context,
      IconData icon,
      String title,
      VoidCallback onTap,
      ) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: theme.primaryColor, // primaryRed
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor, // beige
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor, // darkRed
            ),
            accountName: Text(
              _user.name,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              _user.phone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.primaryColor,
              backgroundImage: _user.profileImage.isNotEmpty
                  ? NetworkImage(_user.profileImage)
                  : null,
              child: _user.profileImage.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
          ),

          _buildTile(context, Icons.local_offer, 'العروض الخاصة', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OffersScreen()),
            );
          }),

          _buildTile(context, Icons.home, 'الرئيسية', () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(user: _user),
              ),
            );
          }),

          _buildTile(context, Icons.person, 'ملفي الشخصي', () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(user: _user),
              ),
            );
          }),

          _buildTile(context, Icons.receipt_long, 'طلباتي السابقة', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrdersHistoryScreen(
                  customerId: _user.id.toString(),
                ),
              ),
            );
          }),

          _buildTile(context, Icons.location_on_outlined, 'عناوين التوصيل', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddAddressScreen(user: _user),
              ),
            );
          }),

          const Spacer(),

          Divider(color: theme.primaryColor.withOpacity(0.3)),

          _buildTile(context, Icons.logout, 'تسجيل الخروج', () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              ),
            );
          }),
        ],
      ),
    );
  }
}
