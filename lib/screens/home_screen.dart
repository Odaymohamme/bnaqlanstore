// هذا ملف HomeScreen كامل مع تحسين تحميل الصور (fixSupabaseImageUrl + debugPrint)
// استبدل الملف الحالي بهذا الملف.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cashe_manager.dart';
import '../models/user.dart';
import '../models/category.dart';
import '../models/special_offer.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../screens/product_detail.dart';
import '../screens/cart_screen.dart';
import '../screens/register_screen.dart';
import '../screens/search_screen.dart';
import '../screens/recent_items_screen.dart';
import '../widgets/favorites_section.dart';
import '../widgets/recommended_section.dart';
import 'category_items_screen.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  List<Category> _categories = [];
  List<SpecialOffer> _offers = [];
  List<Item> _items = [];

  final Set<String> _favoriteIds = {};
  final List<Item> _favoriteItems = [];
  final List<Item> _recentItems = [];
  bool _loadingRecent = true;

  final Set<String> _addingToCartIds = {};
  final Set<String> _togglingFavoriteIds = {};

  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  Timer? _timer;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadAllInitialData();
    _startAutoSlide();
  }

  @override
  bool get wantKeepAlive => true;

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_offers.isEmpty) return;
      if (_currentPage < _offers.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllInitialData() async {
    setState(() => _loading = true);
    await Future.wait([_loadData(), _loadFavorites(), _loadRecent()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadData() async {
    try {
      final catFuture = _firestore.collection('categories').get();
      final offerFuture = _firestore.collection('special_offers').get();
      final itemFuture = _firestore.collection('items').get();

      final results = await Future.wait([catFuture, offerFuture, itemFuture]);

      final catSnap = results[0] as QuerySnapshot;
      final offerSnap = results[1] as QuerySnapshot;
      final itemSnap = results[2] as QuerySnapshot;

      final cats = catSnap.docs
          .map((d) => Category.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final offers = offerSnap.docs
          .map((d) => SpecialOffer.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final items = itemSnap.docs
          .map((d) => Item.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();

      if (mounted) {
        setState(() {
          _categories = cats;
          _offers = offers;
          _items = items;
        });
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favSnap = await _firestore
          .collection('favorites')
          .where('customer_id', isEqualTo: widget.user.id.toString())
          .get();

      final itemIds = favSnap.docs.map((d) {
        final v = d.data() as Map<String, dynamic>;
        return (v['item_id'] ?? '').toString();
      }).where((id) => id.isNotEmpty).toSet().toList();

      _favoriteIds.clear();
      _favoriteItems.clear();

      if (itemIds.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      const batchSize = 10;
      for (var i = 0; i < itemIds.length; i += batchSize) {
        final chunk = itemIds.sublist(i, i + batchSize > itemIds.length ? itemIds.length : i + batchSize);
        final q = await _firestore.collection('items').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in q.docs) {
          final data = doc.data() as Map<String, dynamic>;
          _favoriteItems.add(Item.fromFirestore(data, doc.id));
        }
      }

      _favoriteIds.addAll(itemIds);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      if (mounted) {
        setState(() {
          _favoriteItems.clear();
          _favoriteIds.clear();
        });
      }
    }
  }

  Future<void> _loadRecent() async {
    if (mounted) setState(() => _loadingRecent = true);
    try {
      final snapshot = await _firestore
          .collection('purchased')
          .doc(widget.user.id.toString())
          .collection('items')
          .orderBy('purchaseDate', descending: true)
          .limit(10)
          .get();

      final recent = snapshot.docs
          .map((doc) => Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (mounted) {
        setState(() {
          _recentItems.clear();
          _recentItems.addAll(recent);
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent items: $e');
    }
    if (mounted) setState(() => _loadingRecent = false);
  }

  Future<void> _toggleFavorite(Item item) async {
    final itemId = item.id;
    if (_togglingFavoriteIds.contains(itemId)) return;
    _togglingFavoriteIds.add(itemId);

    final isFav = _favoriteIds.contains(itemId);
    final ref = _firestore.collection('favorites');

    try {
      if (isFav) {
        final q = await ref
            .where('customer_id', isEqualTo: widget.user.id.toString())
            .where('item_id', isEqualTo: itemId)
            .get();
        for (var doc in q.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          setState(() {
            _favoriteIds.remove(itemId);
            _favoriteItems.removeWhere((ei) => ei.id == itemId);
          });
        }
      } else {
        await ref.add({
          'customer_id': widget.user.id.toString(),
          'item_id': itemId,
          'created_at': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _favoriteIds.add(itemId);
            if (!_favoriteItems.any((fi) => fi.id == itemId)) {
              _favoriteItems.insert(0, item);
            }
            if (!_recentItems.any((ri) => ri.id == itemId)) {
              _recentItems.insert(0, item);
              if (_recentItems.length > 20) {
                _recentItems.removeRange(20, _recentItems.length);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Favorite toggle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تعديل المفضلة')),
        );
      }
    } finally {
      _togglingFavoriteIds.remove(itemId);
    }
  }

  String fixSupabaseImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // إذا كان signed URL يحتوي على /object/sign/ نحاول استخراج مسار المنتج
    if (url.contains('/object/sign/')) {
      final match = RegExp(r'(/products/[^?\s/]+\.(?:jpg|jpeg|png|webp))').firstMatch(url);
      if (match != null) {
        final path = match.group(1)!;
        return 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public$path';
      }
    }

    if (url.startsWith('http')) return url;

    // اسم ملف فقط => نعيد الاسم ونبني finalUrl في _buildNetworkImage
    return url;
  }

  Widget _buildNetworkImage(String? url, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
    // رابط فارغ → صورة افتراضية
    if (url == null || url.isEmpty) {
      return Image.asset(
        'assets/aqlanassets.jpg',
        fit: fit,
        height: height,
        width: width,
      );
    }

    // لو الرابط موقّع أو رابط كامل HTTP → استخدمه كما هو
    final finalUrl = url.startsWith('http') ? url : 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/products/$url';

    return CachedNetworkImage(
      cacheManager: MyImageCacheManager.instance,
      imageUrl: finalUrl,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, s) => Container(
        height: height,
        width: width,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, s, e) => Image.asset(
        'assets/aqlanassets.jpg',
        fit: fit,
        height: height,
        width: width,
      ),
    );
  }



  Future<void> _addItemToCartFirestore(Item it, {int quantity = 1, String unit = 'حبة'}) async {
    final customerId = widget.user.id.toString();
    final itemId = it.id;
    final cartRef = _firestore.collection('cart');

    if (_addingToCartIds.contains(itemId)) return;

    setState(() => _addingToCartIds.add(itemId));

    try {
      final q = await cartRef
          .where('customer_id', isEqualTo: customerId)
          .where('item_id', isEqualTo: itemId)
          .where('unit', isEqualTo: unit)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final existingQty = int.tryParse((doc.data()['quantity'] ?? '0').toString()) ?? 0;
        final newQty = existingQty + quantity;
        await doc.reference.update({
          'quantity': newQty.toString(),
          'price': it.price.toString(),
        });
      } else {
        await cartRef.add({
          'customer_id': customerId,
          'item_id': itemId,
          'item_name': it.name,
          'price': it.price.toString(),
          'quantity': quantity.toString(),
          'unit': unit,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تمت إضافة ${it.name} إلى السلة')),
        );
      }
    } catch (e) {
      debugPrint('Add to cart error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل إضافة ${it.name} إلى السلة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCartIds.remove(itemId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // لازم لأننا نستخدم AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحبًا ${widget.user.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(user: widget.user))),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              if (widget.user.id == 0) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("تنبيه"),
                    content: const Text("⚠ يجب تسجيل الدخول لمشاهدة السلة"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("متابعة كزائر")),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                        },
                        child: const Text("تسجيل الدخول"),
                      ),
                    ],
                  ),
                );
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(user: widget.user)));
            },
          ),
        ],
      ),
      drawer: AppDrawer(user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await _loadAllInitialData();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           //const Text('التصنيفات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'التصنيفات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AllCategoriesScreen()),
                    );
                  },
                  child: const Row(
                    children: [
                      Text('عرض الكل', style: TextStyle(color: Colors.blue)),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                    ],
                  ),
                ),
              ],
            )

            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryItemsScreen(user: widget.user, categoryId: c.id, categoryName: c.name))),
                    child: Chip(label: Text(c.name), backgroundColor: Colors.blue.shade100),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('العروض المميزة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _offers.length,
                itemBuilder: (context, index) {
                  final o = _offers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(fit: StackFit.expand, children: [
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: Item(
                            id: o.itemId,
                            name: o.name,
                            price: o.newPrice.toString(),
                            imageUrl: o.image,
                            categoryId: o.categoryId,
                            description: o.description,
                          ), user: widget.user))),
                          child: _buildNetworkImage(o.image),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent]),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('الأصناف المشابهة لطلباتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              RecommendedSection(user: widget.user),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: _loadingRecent
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recentItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final it = _recentItems[i];
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: it, user: widget.user))),
                    child: Container(
                      width: 140,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), child: _buildNetworkImage(it.imageUrl, height: 120, width: 140)),
                        Padding(padding: const EdgeInsets.all(8.0), child: Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('المفضلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('المفضلة')), body: FavoritesSection(user: widget.user))));
                },
                child: const Row(children: [Text('عرض الكل'), Icon(Icons.arrow_forward_ios, size: 16)]),
              ),
            ]),
            const SizedBox(height: 8),
            _favoriteItems.isEmpty
                ? const SizedBox(height: 80, child: Center(child: Text('لا توجد عناصر في المفضلة')))
                : SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _favoriteItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, idx) {
                  final fi = _favoriteItems[idx];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: fi, user: widget.user))),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: SizedBox(
                        width: 180,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: _buildNetworkImage(fi.imageUrl, height: 90, width: 120))),
                          Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(fi.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('${fi.price} ريال', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ])),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.58),
              itemBuilder: (_, idx) {
                final it = _items[idx];
                final isFav = _favoriteIds.contains(it.id);

                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: it, user: widget.user))),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Stack(children: [
                        SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: _buildNetworkImage(it.imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.4),
                            radius: 20,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white, size: 20),
                              onPressed: () => _toggleFavorite(it),
                            ),
                          ),
                        ),
                      ]),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text('${it.price} ريال', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _addingToCartIds.contains(it.id)
                                ? null
                                : () async {
                              await _addItemToCartFirestore(it, quantity: 1, unit: 'حبة');
                              await _loadRecent();
                            },
                            child: _addingToCartIds.contains(it.id)
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("إضافة إلى السلة", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}