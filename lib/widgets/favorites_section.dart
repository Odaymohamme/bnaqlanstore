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

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      // 1. جلب وثائق المفضلة للمستخدم الحالي
      final favSnap = await _firestore
          .collection('favorites')
          .where('customer_id', isEqualTo: widget.user.id.toString())
          .get();

      // 2. استخراج معرفات الأصناف (item_id) من وثائق المفضلة
      final ids = favSnap.docs
          .map((d) => (d['item_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      List<Item> items = [];

      // 3. جلب بيانات كل صنف بشكل منفصل باستخدام معرفه
      for (var id in ids) {
        final doc = await _firestore.collection('items').doc(id).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            items.add(Item.fromFirestore(data, doc.id));
          }
        }
      }

      setState(() => _favoriteItems = items);
    } catch (e) {
      debugPrint("Error loading favorites section: $e");
    }
    setState(() => _loading = false);
  }

  Future<void> _removeFavorite(Item item) async {
    try {
      // البحث عن وثيقة المفضلة وحذفها
      final q = await _firestore
          .collection('favorites')
          .where('customer_id', isEqualTo: widget.user.id.toString())
          .where('item_id', isEqualTo: item.id)
          .get();

      for (var d in q.docs) {
        await d.reference.delete();
      }

      // تحديث واجهة المستخدم فوراً
      setState(() {
        _favoriteItems.removeWhere((i) => i.id == item.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تمت إزالة ${item.name} من المفضلة")));
      }
    } catch (e) {
      debugPrint("Remove favorite error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدوث خطأ أثناء إزالة العنصر من المفضلة')));
      }
    }
  }

  Future<void> _addToCart(Item item) async {
    if (widget.user.id == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("يجب تسجيل الدخول لإضافة المنتجات إلى السلة")));
      }
      return;
    }

    if (item.isSoldOut) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("هذا الصنف غير متوفر حالياً")));
      }
      return;
    }

    // استدعاء خدمة API لإضافة المنتج إلى السلة
    final ok = await ApiService.addToCart(
        customerId: widget.user.id,
        itemId: item.id,
        itemName: item.name,
        price: item.price,
        quantity: 1);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تمت إضافة ${item.name} إلى السلة ✅")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فشل الإضافة إلى السلة ❌")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favoriteItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text("لا توجد عناصر في المفضلة", style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return GridView.builder(
      // يستخدم shrinkWrap و NeverScrollableScrollPhysics عندما يكون داخل SingleChildScrollView
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _favoriteItems.length,
      padding: const EdgeInsets.symmetric(vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68, // نسبة العرض إلى الارتفاع للبطاقة
      ),
      itemBuilder: (_, i) {
        final item = _favoriteItems[i];

        return Card(
          elevation: 3,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ProductDetail(item: item, user: widget.user))),
              child: Stack(children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(item.imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                          'assets/aqlanassets.jpg',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover)),
                ),
                if (item.isSoldOut)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('نفدت الكمية !',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
                // زر إزالة من المفضلة
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    radius: 18,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () => _removeFavorite(item)),
                  ),
                ),
              ]),
            ),

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
                    Text("${item.price} ريال",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ]),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: item.isSoldOut ? null : () => _addToCart(item),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: item.isSoldOut ? Colors.grey : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: Text(item.isSoldOut ? 'نفدت الكمية' : 'إضافة إلى السلة',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            )
          ]),
        );
      },
    );
  }
}