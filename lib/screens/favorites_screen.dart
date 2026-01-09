// lib/screens/favorites_screen.dart
// شاشة عرض المفضلة بالكامل: تحميل من Firestore، إضافة للسلة، حذف من المفضلة.

import 'package:aqlanstore/screens/product_detail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import '../models/item.dart';
import '../services/api_service.dart';

class FavoritesScreen extends StatefulWidget {
  final User user;
  const FavoritesScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<Item> _favorites = [];
  bool _loading = true;
  final Set<String> _addingToCart = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final cust = widget.user.id.toString();
      final favSnap = await _firestore.collection('favorites').where('customer_id', isEqualTo: cust).get();
      final itemIds = favSnap.docs.map((d) => (d.data()['item_id'] ?? '').toString()).where((id) => id.isNotEmpty).toSet().toList();

      _favorites.clear();
      if (itemIds.isNotEmpty) {
        const batch = 10;
        for (var i = 0; i < itemIds.length; i += batch) {
          final end = (i + batch < itemIds.length) ? i + batch : itemIds.length;
          final chunk = itemIds.sublist(i, end);
          final itemsSnap = await _firestore.collection('items').where('item_id', whereIn: chunk).get();
          for (var d in itemsSnap.docs) {
            try {
              _favorites.add(Item.fromFirestore(d.data(), d.id));
            } catch (e) {
              debugPrint('Error parsing favorite item ${d.id}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addToCart(Item it) async {
    final key = it.id;
    if (_addingToCart.contains(key)) return;
    setState(() => _addingToCart.add(key));
    try {
      final ok = await ApiService.addToCartFromDetail(
        customerId: widget.user.id,
        itemId: int.tryParse(it.id) ?? it.idInt,
        itemName: it.name,
        price: double.tryParse(it.price) ?? 0.0,
        quantity: 1,
        unit: 'حبة',
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? "تمت الإضافة للسلة ✅" : "فشل الإضافة ❌")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإضافة: $e')));
    } finally {
      setState(() => _addingToCart.remove(key));
    }
  }

  Future<void> _removeFavorite(String itemId) async {
    try {
      final cust = widget.user.id.toString();
      final snaps = await _firestore.collection('favorites').where('customer_id', isEqualTo: cust).where('item_id', isEqualTo: itemId).get();
      for (var d in snaps.docs) {
        await _firestore.collection('favorites').doc(d.id).delete();
      }
      _favorites.removeWhere((e) => e.id == itemId);
      setState(() {});
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف المفضلة')));
    }
  }

  String _fixImage(String url) {
    if (url.startsWith('http')) return url;
    return "https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/products/$url";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة'), backgroundColor: const Color(0xFFC62828)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? const Center(child: Text('لا توجد عناصر في المفضلة'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _favorites.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final it = _favorites[i];
          final img = it.imageUrl.isNotEmpty ? _fixImage(it.imageUrl) : '';
          return Card(
            child: ListTile(
              leading: img.isNotEmpty ? CachedNetworkImage(imageUrl: img, width: 64, height: 64, fit: BoxFit.cover, errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', width: 64, height: 64, fit: BoxFit.cover)) : Image.asset('assets/aqlanassets.jpg', width: 64, height: 64, fit: BoxFit.cover),
              title: Text(it.name),
              subtitle: Text('${it.price} ريال'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _removeFavorite(it.id)),
                ElevatedButton.icon(onPressed: () => _addToCart(it), icon: const Icon(Icons.add_shopping_cart), label: const Text('أضف'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828))),
              ]),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: it, user: widget.user))),
            ),
          );
        },
      ),
    );
  }
}