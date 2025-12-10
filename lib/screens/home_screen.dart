import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/connection_service.dart';
import '../utils/image_cashe_manager.dart';
import '../models/user.dart';
import '../models/category.dart';
import '../models/special_offer.dart';
import '../models/item.dart';

import '../widgets/app_drawer.dart';
import '../widgets/app_image.dart';
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
  // خريطة لتسهيل إيجاد الصنف بواسطة المعرف
  Map<String, Item> _itemsById = {};


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
    ConnectionService.onConnectionChange.listen((hasInternet) {
      if (!hasInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ لا يوجد اتصال بالإنترنت'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
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
    _firestore.collection('items').limit(50).get(),

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

  /// 🕒 تحميل آخر المشتريات لاتزال غير فعالة
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

  /// 🔄 تفعيل/إلغاء المفضلة لعنصر محدد
  Future<void> _toggleFavorite(Item it) async {
    final itemId = it.id;
    final customerId = widget.user.id.toString();
    final favDocId = '${customerId}_$itemId'; // مستند مركب لتسهيل الحذف
    final favRef = _firestore.collection('favorites').doc(favDocId);

    if (_togglingFavoriteIds.contains(itemId)) return;

    setState(() => _togglingFavoriteIds.add(itemId));

    try {
      final snapshot = await favRef.get();
      if (snapshot.exists) {
        // إزالة
        await favRef.delete();

        _favoriteIds.remove(itemId);
        _favoriteItems.removeWhere((e) => e.id == itemId);
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإزالة من المفضلة')));
      } else {
        // إضافة
        await favRef.set({
          'customer_id': customerId,
          'item_id': itemId,
          'created_at': FieldValue.serverTimestamp(),
        });

        _favoriteIds.add(itemId);
        // أضف العنصر إلى قائمة المفضلات المحلية فورًا
        _favoriteItems.insert(0, it);
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضيف إلى المفضلة')));
      }
    } catch (e) {
      debugPrint('❌ خطأ عند تبديل المفضلة: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء تحديث المفضلة')));
    } finally {
      setState(() => _togglingFavoriteIds.remove(itemId));
    }
  }

  /// 🔁 مساعدة: هل هذا العنصر في المفضلة؟
  bool _isFavorite(Item it) => _favoriteIds.contains(it.id);

  /// 🖼 تصحيح رابط الصور من Supabase
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


              /// 🗂 قسم الفئات
              /// ===== شبكة الفئات 4x4 قابلة للتمرير داخل صندوق + زر "عرض الكل" =====
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // سطر العنوان + زر عرض الكل
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('التصنيفات',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CategoryItemsScreen(
                                    user: widget.user,
                                    categoryId: null,
                                    categoryName: null,
                                  ),
                                ),
                              );
                            },
                            child: const Text('عرض الكل'),
                          ),
                        ],
                      ),
                    ),

                    LayoutBuilder(builder: (context, constraints) {
                      final screenW = MediaQuery.of(context).size.width;
                      const outerPadding = 16.0;
                      const crossSpacing = 8.0;
                      const mainSpacing = 8.0;
                      const columns = 3;
                      const visibleRows = 2;

                      final availableWidth =
                          screenW - (outerPadding * 3) - (crossSpacing * (columns - 1));
                      final itemWidth = (availableWidth / columns).clamp(64.0, 220.0);
                      final avatarSize = (itemWidth * 0.67).clamp(44.0, 80.0);
                      const textHeight = 28.0; // ارتفاع ثابت للنص
                      const verticalSpacing = 6.0; // المسافة بين الصورة والنص

                      // ارتفاع صف = الصورة + المسافة + النص + mainSpacing
                      final rowHeight = avatarSize + verticalSpacing + textHeight + mainSpacing;
                      // gridHeight = ارتفاع صف * عدد الصفوف المراد عرضها
                      final gridHeight =
                          (rowHeight * visibleRows) + mainSpacing; // safety margin

                      return SizedBox(
                        height: gridHeight,
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: outerPadding / 2),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: mainSpacing,
                            crossAxisSpacing: crossSpacing,
                            childAspectRatio: itemWidth / (avatarSize + verticalSpacing + textHeight),
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, i) {
                            final c = _categories[i];
                            final imageUrl = (c.image.isNotEmpty)
                                ? c.image
                                : (c.imageUrl.isNotEmpty ? c.imageUrl : '');

                            return InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CategoryItemsScreen(
                                    user: widget.user,
                                    categoryId: c.id,
                                    categoryName: c.name,
                                  ),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: avatarSize,
                                    height: avatarSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[200],
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                            offset: Offset(0, 2))
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        width: avatarSize,
                                        height: avatarSize,
                                        placeholder: (_, __) =>
                                            Container(color: Colors.grey[200]),
                                        errorWidget: (_, __, ___) => Image.asset(
                                          'assets/aqlanassets.jpg',
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                          : Image.asset('assets/aqlanassets.jpg',
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(height: verticalSpacing),
                                  SizedBox(
                                    height: textHeight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        c.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

              /// ===== نهاية شبكة الفئات =====


              const SizedBox(height: 24),

              /// 🎁 قسم العروض المميزة

              const Text('العروض المميزة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryRed)),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('special_offers')
                      .orderBy('created_at', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد عروض حالياً'));
                    }

                    final docs = snapshot.data!.docs;

                    return PageView.builder(
                      controller: _pageController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final offer = docs[index].data();

                        final itemId = (offer['item_id'] ?? '').toString().trim();
                        final newPrice = (offer['new_price'] ?? '').toString();
                        final oldPrice = (offer['old_price'] ?? '').toString();
                        final offerType = (offer['offer_type'] ?? '').toString();

                        if (itemId.isEmpty) {
                          return const SizedBox();
                        }

                        // جلب بيانات المنتج من items
                        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('items')
                              .where('item_id', isEqualTo: itemId)
                              .limit(1)
                              .get(),
                          builder: (context, itemSnap) {
                            if (!itemSnap.hasData || itemSnap.data!.docs.isEmpty) {
                              return const SizedBox();
                            }

                            final item = itemSnap.data!.docs.first.data();

                            final imageUrl = (item['image_url'] ??
                                item['image'] ??
                                '')
                                .toString();

                            final name = (item['name'] ?? '').toString();
                            final description =
                            (item['description'] ?? '').toString();

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    /// صورة الكارد
                                    InkWell(
                                      onTap: () {
                                        final detailItem = Item(
                                          id: itemId,
                                          name: name,
                                          price: newPrice,
                                          imageUrl: imageUrl,
                                          description: description,
                                          categoryId: '',
                                        );

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductDetail(item: detailItem, user: widget.user),
                                          ),
                                        );
                                      },
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                                      ),
                                    ),

                                    /// تدرج غامق أسفل الصورة
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),

                                    /// النصوص فوق الصورة
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      left: 12,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                newPrice,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                oldPrice,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: Colors.orange,
                                                    borderRadius:
                                                    BorderRadius.circular(20)),
                                                child: Text(
                                                  offerType,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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
                              child:CachedNetworkImage(
                                imageUrl: _fixSupabaseImageUrl(it.imageUrl),
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) => Image.asset(
                                  'assets/aqlanassets.jpg',
                                  fit: BoxFit.cover,
                                ),
                              )

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
                        Text('عرض الكل', style: TextStyle(color: kPrimaryRed)),
                        Icon(Icons.arrow_forward_ios, size: 16, color: kPrimaryRed)
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
                                            fontWeight: FontWeight.bold,
                                            color: kPrimaryRed))
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
                                    child: CachedNetworkImage(
                                      imageUrl: _fixSupabaseImageUrl(it.imageUrl),
                                      fit: BoxFit.cover,
                                      memCacheWidth: 400,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      errorWidget: (context, url, error) => Image.asset(
                                        'assets/aqlanassets.jpg',
                                        fit: BoxFit.cover,
                                      ),
                                    )

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

                                  // ----- هنا أضفنا زر القلب للمفضلة -----
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Material(
                                      color: Colors.white.withOpacity(0.95),
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: InkWell(
                                        onTap: () async {
                                          // منع تنشيط التبديل عند وجود عملية جارية على نفس العنصر
                                          if (_togglingFavoriteIds.contains(it.id)) return;
                                          await _toggleFavorite(it);
                                        },
                                        customBorder: const CircleBorder(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: _togglingFavoriteIds.contains(it.id)
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                              : Icon(
                                            _isFavorite(it) ? Icons.favorite : Icons.favorite_border,
                                            color: _isFavorite(it) ? Colors.red : Colors.black54,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // ----- نهاية زر القلب -----
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
