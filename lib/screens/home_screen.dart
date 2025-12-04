import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/image_cashe_manager.dart';
import '../models/user.dart';
import '../models/category.dart';
import '../models/special_offer.dart';
import '../models/item.dart';

import '../widgets/app_drawer.dart';
import '../widgets/favorites_section.dart';
import '../widgets/recommended_section.dart';

import '../screens/product_detail.dart';
import '../screens/cart_screen.dart';
import '../screens/register_screen.dart';
import '../screens/search_screen.dart';
import 'category_items_screen.dart';

/// 🎨 ألوان ثابتة للتطبيق
const kPrimaryRed = Color(0xFFC62828);
const kBeige = Color(0xFFF3E9DD);

/// 🏠 الشاشة الرئيسية
class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController(viewportFraction: 0.85);

  bool _loading = true;
  bool _loadingRecent = true;

  List<Category> _categories = [];
  List<SpecialOffer> _offers = [];
  List<Item> _items = [];
  List<Item> _favoriteItems = [];
  List<Item> _recentItems = [];

  final Set<String> _favoriteIds = {};
  final Set<String> _addingToCartIds = {};
  final Set<String> _togglingFavoriteIds = {};

  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadAllInitialData();
    _startAutoSlide();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// ⏱ تشغيل السلايدر التلقائي للعروض
  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_offers.isEmpty) return;
      _currentPage = (_currentPage + 1) % _offers.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// 📦 تحميل جميع البيانات الأولية
  Future<void> _loadAllInitialData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadData(),
      _loadFavorites(),
      _loadRecent(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  /// 🗂 تحميل الفئات والعروض والمنتجات
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _firestore.collection('categories').get(),
        _firestore.collection('special_offers').get(),
        _firestore.collection('items').get(),
      ]);

      _categories = results[0].docs
          .map((d) => Category.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();

      _offers = results[1].docs
          .map((d) => SpecialOffer.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();

      _items = results[2].docs
          .map((d) => Item.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ خطأ في تحميل البيانات: $e');
    }
  }

  /// ❤️ تحميل المفضلة
  Future<void> _loadFavorites() async {
    try {
      final favSnap = await _firestore
          .collection('favorites')
          .where('customer_id', isEqualTo: widget.user.id.toString())
          .get();

      final itemIds = favSnap.docs
          .map((d) => (d.data()['item_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      _favoriteIds.clear();
      _favoriteItems.clear();

      // تقسيم الاستعلام إلى دفعات لتجنب قيود Firestore
      const batchSize = 10;
      for (var i = 0; i < itemIds.length; i += batchSize) {
        final chunk = itemIds.sublist(i, (i + batchSize).clamp(0, itemIds.length));
        final q = await _firestore
            .collection('items')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        _favoriteItems.addAll(q.docs.map(
                (doc) => Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)));
      }

      _favoriteIds.addAll(itemIds);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ خطأ في تحميل المفضلة: $e');
    }
  }

  /// 🕒 تحميل آخر المشتريات
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

      _recentItems = snapshot.docs
          .map((doc) => Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ خطأ في تحميل المشتريات: $e');
    }
    if (mounted) setState(() => _loadingRecent = false);
  }

  /// 🛒 إضافة صنف إلى السلة
  Future<void> _addItemToCartFirestore(Item it,
      {int quantity = 1, String unit = 'حبة'}) async {
    if (it.isSoldOut) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الصنف غير متوفر حالياً')));
      return;
    }

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
        final existingQty =
            int.tryParse((doc.data()['quantity'] ?? '0').toString()) ?? 0;
        await doc.reference.update({
          'quantity': (existingQty + quantity).toString(),
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

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تمت إضافة ${it.name} إلى السلة')));
    } catch (e) {
      debugPrint('❌ خطأ في إضافة للسلة: $e');
    } finally {
      setState(() => _addingToCartIds.remove(itemId));
    }
  }

  /// 🖼 تصحيح رابط الصور من Supabase
  String _fixSupabaseImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/products/$url';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
        backgroundColor: kBeige,
        appBar: AppBar(
            backgroundColor: kPrimaryRed,
            title: Text('مرحبًا ${widget.user.name}',
                style: const TextStyle(color: Colors.white)),
            actions: [
        IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SearchScreen(user: widget.user)))),
    IconButton(
    icon: const Icon(Icons.shopping_cart, color: Colors.white),
    onPressed: () {
    if (widget.user.id == 0) {
    showDialog( context:context,
    builder: (ctx) => AlertDialog(
    title: const Text("تنبيه"),
    content: const Text("⚠ يجب تسجيل الدخول لمشاهدة السلة"),
    actions: [
    TextButton(
    onPressed: () => Navigator.pop(ctx),
    child: const Text("متابعة كزائر")),
    ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryRed),
    onPressed: () {
    Navigator.pop(ctx);
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => const RegisterScreen()));
    },
    child: const Text("تسجيل الدخول",
    style: TextStyle(color: Colors.white)),
    ),
    ],
    ),
    );
    return;
    }
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => CartScreen(user: widget.user)));
    },
    ),
    ],
    ),
    drawer: AppDrawer(user: widget.user),
    body: _loading
    ? const Center(child: CircularProgressIndicator(color: kPrimaryRed))
        : RefreshIndicator(
    color: kPrimaryRed,
    backgroundColor: kBeige,
    onRefresh: _loadAllInitialData,
    child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const SizedBox(height: 10),

    /// 🗂 قسم الفئات
    SizedBox(
    height: 50,
    child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _categories.length,
    separatorBuilder: (_, __) => const SizedBox(width: 8),
    itemBuilder: (_, i) {
    final c = _categories[i];
    return GestureDetector(
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => CategoryItemsScreen(
    user: widget.user,
    categoryId: c.id,
    categoryName: c.name))),
    child: Chip(
    label: Text(c.name),
    backgroundColor: kPrimaryRed.withOpacity(0.15),
    labelStyle: const TextStyle(
    color: kPrimaryRed,
    fontWeight: FontWeight.w600),
    ),
    );
    },
    ),
    ),
    const SizedBox(height: 24),

    /// 🎁 قسم العروض المميزة
    const Text('العروض المميزة',
    style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: kPrimaryRed)),
    const SizedBox(height: 10),
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
    child: Stack(
    fit: StackFit.expand,
    children: [
    InkWell(
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => ProductDetail(
    item: Item(
    id: o.itemId,
    name: o.name,
    price: o.newPrice.toString(),
    imageUrl: o.image,
    categoryId: o.categoryId,
    description: o.description),
    user: widget.user))),
    child: Image.network(
    o.image,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Image.asset(
    'assets/aqlanassets.jpg',
    fit: BoxFit.cover),
    ),
    ),
    Container(
    decoration: BoxDecoration(
    gradient: LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [
    kPrimaryRed.withOpacity(0.45),
    Colors.transparent
    ],
    ),
    ),
    ),
    ],
    ),
    ),
    );
    },
    ),
    ),
    const SizedBox(height: 24),

    /// 🔮 قسم الموصى بها
    const Text('الأصناف المشابهة لطلباتك',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: kPrimaryRed)),
    RecommendedSection(user: widget.user),
    const SizedBox(height: 14),

    /// 🕒 قسم المشتريات الأخيرة
    const Text('تم شراؤها مؤخراً',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: kPrimaryRed)),
    SizedBox(
    height: 240,
    child: _loadingRecent
    ? const Center(
    child: CircularProgressIndicator(color: kPrimaryRed))
        : ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _recentItems.length,
    separatorBuilder: (_, __) =>
    const SizedBox(width: 12),
    itemBuilder: (_, i) {
    final it = _recentItems[i];
    return InkWell(
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) =>
    ProductDetail(item: it, user: widget.user))),
    child: Container(
    width: 140,
    decoration: BoxDecoration(
    border: Border.all(
    color: kPrimaryRed.withOpacity(.12)),
    borderRadius: BorderRadius.circular(8),
    color: Colors.white,
    boxShadow: [
    BoxShadow(
    color: kPrimaryRed.withOpacity(.04),
    blurRadius: 3,
    offset: const Offset(0, 3))
    ],
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    ClipRRect(
    borderRadius: const BorderRadius.vertical(
    top: Radius.circular(8)),
    child: Image.network(
    _fixSupabaseImageUrl(it.imageUrl),
    height: 120,
    width: 140,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) =>
    Image.asset('assets/aqlanassets.jpg'),
    ),
    ),
    Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(it.name,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
    fontWeight: FontWeight.bold)),
    ),
    ],
    ),
    ),
    );
    },
    ),
    ),
    const SizedBox(height: 24),

    /// ❤️ قسم المفضلة
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    const Text('المفضلة',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: kPrimaryRed)),
    TextButton(
    onPressed: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => Scaffold(
    appBar: AppBar(
    title: const Text('المفضلة')),
    body: FavoritesSection(user: widget.user),
    )));
    },
    child: const Row(
    children: [
    Text('عرض الكل',
    style: TextStyle(color: kPrimaryRed)),
    Icon(Icons.arrow_forward_ios,
    size: 16, color: kPrimaryRed)
    ],
    ),
    )
    ],
    ),
    const SizedBox(height: 12),
    _favoriteItems.isEmpty
    ? const SizedBox(
    height: 80,
    child: Center(child: Text('لا توجد عناصر في المفضلة')))
        : SizedBox(
    height: 200,
    child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _favoriteItems.length,
    separatorBuilder: (_, __) =>
    const SizedBox(width: 12),
    itemBuilder: (_, idx) {
    final fi = _favoriteItems[idx];
    return GestureDetector(
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) =>
    ProductDetail(item: fi, user: widget.user))),
    child: Card(
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    color: Colors.white,
    child: SizedBox(
    width: 180,
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.stretch,
    children: [
    Expanded(
    child: ClipRRect(
    borderRadius:
    const BorderRadius.vertical(
    top: Radius.circular(12)),
    child: Image.network(
    _fixSupabaseImageUrl(fi.imageUrl),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) =>
    Image.asset('assets/aqlanassets.jpg'),
    ),
    ),
    ),
    Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
    crossAxisAlignment:
    CrossAxisAlignment.start,
    children: [
    Text(fi.name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
    fontSize: 13)),
    const SizedBox(height: 4),
    Text('${fi.price} ريال',
    style: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,                                                        color: kPrimaryRed))
    ],
    ),
    )
    ],
    ),
    ),
    ),
    );
    },
    ),
    ),
      const SizedBox(height: 24),

      /// 🛍 قسم المنتجات (GridView)
      const Text('المنتجات',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kPrimaryRed)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,          // عدد الأعمدة
          childAspectRatio: 0.6,      // نسبة العرض إلى الارتفاع (يمكن تعديلها حسب التصميم)
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (_, idx) {
          final it = _items[idx];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetail(item: it, user: widget.user),
              ),
            ),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              shadowColor: kPrimaryRed.withOpacity(0.2),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// صورة المنتج (تتكيف مع المساحة بشكل تلقائي)
                  Flexible(
                    flex: 6,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              _fixSupabaseImageUrl(it.imageUrl),
                              fit: BoxFit.cover,          // تغطية كاملة
                              alignment: Alignment.center, // تمركز الصورة
                              errorBuilder: (_, __, ___) =>
                                  Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                            ),
                          ),
                          if (it.isSoldOut)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'نفدت الكمية !',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  /// معلومات المنتج + زر السلة
                  Flexible(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${it.price} ريال',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryRed,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryRed,
                              minimumSize: const Size.fromHeight(36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _addItemToCartFirestore(it),
                            icon: const Icon(Icons.add_shopping_cart,
                                size: 16, color: Colors.white),
                            label: const Text("أضف للسلة",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      )
      ],
    ),
    ),
    ),
    );
  }
}
