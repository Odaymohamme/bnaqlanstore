// lib/widgets/favorites_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import '../models/user.dart';
import '../screens/product_detail.dart';
import '../services/api_service.dart';

class FavoritesSection extends StatefulWidget {
  final User user;

  const FavoritesSection({Key? key, required this.user}) : super(key: key);

  @override
  State<FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<FavoritesSection> {
  final _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  List<Item> _favoriteItems = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// ✅ تحميل الأصناف المفضلة من Firestore
  Future<void> _loadFavorites() async {
    setState(() => _loading = true);

    try {
      final favSnap = await _firestore
          .collection('favorites')
          .where('customer_id', isEqualTo: widget.user.id.toString())
          .get();

      final ids = favSnap.docs
          .map((d) => (d['item_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      List<Item> items = [];

      for (var id in ids) {
        final doc = await _firestore.collection('items').doc(id).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            items.add(Item.fromFirestore(data, doc.id));
          }
        }
      }

      setState(() {
        _favoriteItems = items;
      });
    } catch (e) {
      debugPrint("Error loading favorites section: $e");
    }

    setState(() => _loading = false);
  }

  /// ✅ إزالة من المفضلة
  Future<void> _removeFavorite(Item item) async {
    try {
      final q = await _firestore
          .collection('favorites')
          .where('customer_id', isEqualTo: widget.user.id.toString())
          .where('item_id', isEqualTo: item.id)
          .get();

      for (var d in q.docs) {
        await d.reference.delete();
      }

      setState(() {
        _favoriteItems.removeWhere((i) => i.id == item.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ تمت إزالة ${item.name} من المفضلة"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Remove favorite error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء إزالة العنصر من المفضلة')),
        );
      }
    }
  }

  /// ✅ إضافة إلى السلة
  Future<void> _addToCart(Item item) async {
    if (widget.user.id == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠ يجب تسجيل الدخول لإضافة المنتجات إلى السلة")),
        );
      }
      return;
    }

    final ok = await ApiService.addToCart(
      customerId: widget.user.id,
      itemId: item.id,
      itemName: item.name,
      price: item.price,
      quantity: 1,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ تمت إضافة ${item.name} إلى السلة")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ فشل الإضافة إلى السلة")),
      );
    }
  }

  /// ✅ كارد المفضلة + زر السلة
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favoriteItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text(
            "لا توجد عناصر في المفضلة",
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _favoriteItems.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (_, i) {
        final item = _favoriteItems[i];

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصورة + قلب الحذف
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetail(item: item, user: widget.user),
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        item.imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/aqlanassets.jpg',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () => _removeFavorite(item),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // الاسم والسعر
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      "${item.price} ريال",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ✅ ✅ زر إضافة إلى السلة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _addToCart(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "إضافة إلى السلة",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
