// lib/screens/home_screen.dart
// محدث: تصغير أزرار، التحقق من نفاد الكمية (isSoldOut)، تحميل مزيد من التوصيات عند التمرير، تكبير كارد التوصيات قليلاً,
// جعل التصنيفات أفقية (قابلة للتمرير) كشبكة 3x2، لم تتغير واجهات أخرى.

import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/item.dart';
import '../models/category.dart';
import '../models/special_offer.dart';
import '../services/api_service.dart';
import '../services/connection_service.dart';

import '../widgets/app_drawer.dart';
import '../widgets/recommended_section.dart';

import 'category_items_screen.dart';
import 'favorites_screen.dart';
import 'cart_screen.dart';
import 'product_detail.dart';
import 'search_screen.dart';

const kPrimaryRed = Color(0xFFC62828);

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;

  List<Category> _categories = [];
  List<SpecialOffer> _offers = [];
  List<Item> _items = [];
  List<Item> _favoriteItems = [];
  List<Item> _recommended = [];

  Map<String, Item> _itemsById = {};
  DocumentSnapshot? _lastItemDoc;

  final PageController _pageController = PageController(viewportFraction: 0.86);
  int _currentPage = 0;
  Timer? _timer;

  final ScrollController _scrollController = ScrollController();

  // recommended horizontal controller for infinite load
  final ScrollController _recScrollController = ScrollController();
  bool _loadingMoreRecommended = false;

  bool _hasInternet = true;
  int _cartCount = 0;
  final Set<String> _addingToCartIds = {};

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initAll();
    ConnectionService.onConnectionChange.listen((hasInternet) {
      if (!mounted) return;
      setState(() => _hasInternet = hasInternet);
    });
    _safeAddScrollListener();

    // recommended infinite scroll listener
    _recScrollController.addListener(() {
      if (_recScrollController.position.pixels >= _recScrollController.position.maxScrollExtent - 120) {
        _loadMoreRecommended();
      }
    });
  }

  void _safeAddScrollListener() {
    try {
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
          _loadMoreItems();
        }
      });
    } catch (_) {}
  }

  Future<void> _initAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadData(), _loadFavorites(), _loadCartCount()]);
    await _buildRecommended(initial: true);
    _startAutoSlide();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _scroll_controllerSafeDispose();
    _recScrollController.dispose();
    super.dispose();
  }

  void _scroll_controllerSafeDispose() {
    try {
      _scrollController.dispose();
    } catch (_) {}
  }

  // ---------------------
  // Data loading
  // ---------------------

  Future<void> _loadData() async {
    try {
      final catSnap = await _firestore.collection('categories').get();
      _categories = catSnap.docs.map((d) => Category.fromFirestore(d.data(), d.id)).toList();

      final offersSnap = await _firestore.collection('special_offers').get();
      _offers = offersSnap.docs.map((d) => SpecialOffer.fromFirestore(d.data(), d.id)).toList();

      final itemsSnap = await _firestore.collection('items').limit(200).get();
      final all = itemsSnap.docs.map((d) => Item.fromFirestore(d.data(), d.id)).toList();
      all.shuffle(Random());
      _items = all.take(_pageSize).toList();

      _itemsById = {for (var it in _items) it.id: it};
      if (itemsSnap.docs.isNotEmpty) _lastItemDoc = itemsSnap.docs.last;
    } catch (e, st) {
      debugPrint('Error in _loadData: $e\n$st');
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems) return;
    setState(() => _isLoadingMore = true);
    try {
      final snap = await _firestore.collection('items').limit(200).get();
      final list = snap.docs.map((d) => Item.fromFirestore(d.data(), d.id)).toList();
      list.shuffle(Random());
      final added = <Item>[];
      for (final it in list) {
        if (added.length >= _pageSize) break;
        if (!_itemsById.containsKey(it.id)) {
          added.add(it);
          _itemsById[it.id] = it;
        }
      }
      if (added.isEmpty) {
        _hasMoreItems = false;
      } else {
        _items.addAll(added);
      }
    } catch (e, st) {
      debugPrint('Error loading more items: $e\n$st');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // recommended builds with option to append
  Future<void> _buildRecommended({bool initial = false}) async {
    if (initial) _recommended.clear();
    if (_loadingMoreRecommended) return;
    setState(() => _loadingMoreRecommended = true);
    try {
      final snap = await _firestore.collection('items').limit(200).get();
      final list = snap.docs.map((d) => Item.fromFirestore(d.data(), d.id)).toList();
      list.shuffle(Random());
      // append up to 10 unique items
      for (var it in list) {
        if (_recommended.length >= 30) break; // limit upper bound
        if (!_recommended.any((r) => r.id == it.id) && !_itemsById.containsKey(it.id)) {
          _recommended.add(it);
          _itemsById[it.id] = it;
        } else if (!_recommended.any((r) => r.id == it.id) && !_recommended.any((r) => r.id == it.id)) {
          // fallback: include anyway if not present
          if (!_recommended.any((r) => r.id == it.id)) {
            _recommended.add(it);
            _itemsById[it.id] = it;
          }
        }
        if (_recommended.length % 10 == 0) {
          // stop occasionally to avoid huge append
          break;
        }
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Error building recommended: $e\n$st');
    } finally {
      setState(() => _loadingMoreRecommended = false);
    }
  }

  Future<void> _loadMoreRecommended() async {
    if (_loadingMoreRecommended) return;
    await _buildRecommended();
  }

  Future<void> _loadFavorites() async {
    try {
      _favoriteItems.clear();
      final cust = widget.user.id.toString();
      final favSnap = await _firestore.collection('favorites').where('customer_id', isEqualTo: cust).get();
      final itemIds = favSnap.docs.map((d) => (d.data()['item_id'] ?? '').toString()).where((id) => id.isNotEmpty).toSet().toList();

      if (itemIds.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      const batchSize = 10;
      for (var i = 0; i < itemIds.length; i += batchSize) {
        final end = min(i + batchSize, itemIds.length);
        final chunk = itemIds.sublist(i, end);
        final itemsSnap = await _firestore.collection('items').where('item_id', whereIn: chunk).get();
        for (var d in itemsSnap.docs) {
          try {
            final it = Item.fromFirestore(d.data(), d.id);
            _favoriteItems.add(it);
            _itemsById[it.id] = it;
          } catch (e) {
            debugPrint('fav parse error ${d.id}: $e');
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final cust = widget.user.id.toString();
      int count = 0;
      bool found = false;
      try {
        final cSnap = await _firestore.collection('cart').where('customer_id', isEqualTo: cust).get();
        if (cSnap.docs.isNotEmpty) {
          found = true;
          for (var d in cSnap.docs) {
            final data = d.data();
            final q = data['quantity'];
            if (q is int) count += q;
            else if (q is double) count += q.toInt();
            else count += int.tryParse(q.toString()) ?? 1;
          }
        }
      } catch (_) {}
      if (!found) {
        try {
          final cSnap = await _firestore.collection('cart_items').where('customer_id', isEqualTo: cust).get();
          if (cSnap.docs.isNotEmpty) {
            found = true;
            count = cSnap.docs.length;
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _cartCount = count);
    } catch (e) {
      debugPrint('Error loading cart count: $e');
      if (mounted) setState(() => _cartCount = 0);
    }
  }

  // ---------------------
  // Actions
  // ---------------------

  Future<void> _addToCart(Item item) async {
    if (item.isSoldOut) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠ هذه القطعة نفدت الكمية')));
      return;
    }
    final key = item.id;
    if (_addingToCartIds.contains(key)) return;
    setState(() => _addingToCartIds.add(key));
    try {
      final ok = await ApiService.addToCartFromDetail(
        customerId: widget.user.id,
        itemId: int.tryParse(item.id) ?? item.idInt,
        itemName: item.name,
        price: double.tryParse(item.price.replaceAll(',', '')) ?? 0.0,
        quantity: 1,
        unit: 'حبة',
      );
      if (ok) setState(() => _cartCount = _cartCount + 1);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'تمت الإضافة للسلة ✅' : 'فشل الإضافة ❌')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإضافة للسلة: $e')));
    } finally {
      setState(() => _addingToCartIds.remove(key));
    }
  }

  Future<void> _toggleFavorite(Item item) async {
    try {
      final cust = widget.user.id.toString();
      final itemId = item.id;
      final q = await _firestore.collection('favorites').where('customer_id', isEqualTo: cust).where('item_id', isEqualTo: itemId).get();
      if (q.docs.isNotEmpty) {
        for (var d in q.docs) {
          await _firestore.collection('favorites').doc(d.id).delete();
        }
        _favoriteItems.removeWhere((it) => it.id == item.id);
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أزيل من المفضلة')));
        return;
      }
      await _firestore.collection('favorites').add({'customer_id': cust, 'item_id': itemId, 'created_at': FieldValue.serverTimestamp()});
      _favoriteItems.add(item);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضيف إلى المفضلة')));
    } catch (e) {
      debugPrint('Error toggle fav: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ أثناء تعديل المفضلة')));
    }
  }

  bool _isFavoriteItem(Item item) {
    return _favoriteItems.any((it) => it.id == item.id);
  }

  Future<void> _removeFavoriteFromFirestore(Item it) async {
    try {
      final cust = widget.user.id.toString();
      final itemId = it.id;
      final snaps = await _firestore.collection('favorites').where('customer_id', isEqualTo: cust).where('item_id', isEqualTo: itemId).get();
      for (var d in snaps.docs) {
        await _firestore.collection('favorites').doc(d.id).delete();
      }
      _favoriteItems.removeWhere((f) => f.id == it.id);
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حُذِف من المفضلة')));
    } catch (e) {
      debugPrint('Error removing fav: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف المفضلة')));
    }
  }

  String _fixImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/products/$url';
  }
  void _showFullImage(BuildContext context, String img) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: 'item_image_${img.hashCode}',
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: img.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.contain,
              )
                  : Image.asset('assets/aqlanassets.jpg'),
            ),
          ),
        ),
      ),
    );
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_offers.isEmpty) return;
      _currentPage = (_currentPage + 1) % _offers.length;
      if (_pageController.hasClients) {
        try {
          _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        } catch (_) {}
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  // ---------------------
  // Build
  // ---------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      drawer: AppDrawer(user: widget.user),
      appBar: AppBar(
        backgroundColor: kPrimaryRed,
        title: Text('مرحبًا ${widget.user.name}', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(user: widget.user)))),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                onPressed: () {
                  if (widget.user.id == 0) {
                    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('تنبيه'), content: const Text('⚠ يجب تسجيل الدخول لمشاهدة السلة'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('متابعة كزائر'))]));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(user: widget.user)));
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text('$_cartCount', style: const TextStyle(color: kPrimaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _initAll,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Offers carousel
                if (_offers.isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _offers.length,
                      itemBuilder: (context, idx) {
                        final of = _offers[idx];
                        final img = (of.image != null && of.image!.isNotEmpty) ? _fixImageUrl(of.image!) : '';
                        return _offerCard(of, img);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Favorites header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('المفضلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(user: widget.user))), child: const Text('عرض الكل')),
                  ]),
                ),
                if (_favoriteItems.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text('لا توجد عناصر في المفضلة لديك', style: TextStyle(color: Colors.grey[700])))
                else
                  SizedBox(
                    height: 170,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: _favoriteItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final it = _favoriteItems[i];
                        final img = it.imageUrl.isNotEmpty ? _fixImageUrl(it.imageUrl) : '';
                        return SizedBox(
                          width: 150,
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // صورة أصغر داخل الكارد (تقليل الارتفاع)
                              SizedBox(
                                height: 78,
                                width: double.infinity,
                                child: Stack(children: [
                                  Positioned.fill(
                                    child: img.isNotEmpty
                                        ? ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      child: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.grey[200]), errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover)),
                                    )
                                        : ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      child: Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                                    ),
                                  ),
                                  // نفدت الكمية badge
                                  if (it.isSoldOut)
                                    Positioned(
                                      left: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('نفدت الكمية', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ),
                                    ),
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white70,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 18,
                                        icon: const Icon(Icons.add_shopping_cart, color: kPrimaryRed),
                                        onPressed: it.isSoldOut ? null : () => _addToCart(it),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),

                              // نصوص قابلة للتمدد لتجنب overflow
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Flexible(child: Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                    const SizedBox(height: 6),
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Text('${it.price} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryRed)),
                                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20), onPressed: () => _removeFavoriteFromFirestore(it)),
                                    ]),
                                  ]),
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                // Categories: horizontal scroll grid 3x2
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('التصنيفات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryItemsScreen(user: widget.user, categoryId: null, categoryName: 'كل التصنيفات'))), child: const Text('عرض الكل')),
                ])),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // 2 rows -> makes 3x2 visible columns depending on width
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, idx) {
                        final c = _categories[idx];
                        final img = c.image.isNotEmpty ? c.image : '';
                        final imgUrl = img.startsWith('http') ? img : img;
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryItemsScreen(user: widget.user, categoryId: c.id, categoryName: c.name))),
                          child: Column(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imgUrl.isNotEmpty ? CachedNetworkImage(imageUrl: imgUrl, width: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover)) : Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(height: 28, child: Center(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                          ]),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Recommended horizontal (bigger card, add-to-cart + stock check)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: const Text('توصيات لك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 190,
                  child: _recommended.isEmpty
                      ? const Center(child: Text('لا توجد توصيات حالياً'))
                      : ListView.separated(
                    controller: _recScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recommended.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final it = _recommended[i];
                      final img = it.imageUrl.isNotEmpty ? _fixImageUrl(it.imageUrl) : '';
                      return SizedBox(
                        width: 160,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Column(children: [
                            SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: Stack(children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                    child: img.isNotEmpty ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.grey[200]), errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover)) : Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                                  ),
                                ),
                                if (it.isSoldOut)
                                  Positioned(
                                    left: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                                      child: const Text('نفدت الكمية', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                  ),
                              ]),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Flexible(child: Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(height: 12),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text('${it.price} ريال', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryRed)),
                                    ElevatedButton.icon(
                                      onPressed: it.isSoldOut ? null : () => _addToCart(it),
                                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                                      label: const Text('أضف', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryRed, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), minimumSize: const Size(48, 34)),
                                    ),
                                  ]),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Products grid (slightly larger cards, smaller buttons)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: const Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72, // مهم جداً
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, idx) {
                      final it = _items[idx];
                      final img = it.imageUrl.isNotEmpty ? _fixImageUrl(it.imageUrl) : '';

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetail(item: it, user: widget.user),
                          ),
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              /// ---------- الصورة ----------
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () => _showFullImage(context, img),
                                        child: Hero(
                                          tag: 'item_image_${it.id}',
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                            child: img.isNotEmpty
                                                ? CachedNetworkImage(
                                              imageUrl: img,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) =>
                                                  Container(color: Colors.grey[200]),
                                              errorWidget: (_, __, ___) =>
                                                  Image.asset(
                                                    'assets/aqlanassets.jpg',
                                                    fit: BoxFit.cover,
                                                  ),
                                            )
                                                : Image.asset(
                                              'assets/aqlanassets.jpg',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    if (it.isSoldOut)
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'نفدت الكمية',
                                            style: TextStyle(
                                                color: Colors.white, fontSize: 11),
                                          ),
                                        ),
                                      ),

                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.white70,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          iconSize: 18,
                                          icon: Icon(
                                            _isFavoriteItem(it)
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: _isFavoriteItem(it)
                                                ? Colors.red
                                                : kPrimaryRed,
                                          ),
                                          onPressed: () => _toggleFavorite(it),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              /// ---------- التفاصيل ----------
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${it.price} ريال',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: kPrimaryRed,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed:
                                          it.isSoldOut ? null : () => _addToCart(it),
                                          icon: const Icon(
                                            Icons.add_shopping_cart,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'أضف',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kPrimaryRed,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            minimumSize: const Size(50, 36),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                ),

                if (_isLoadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator())),
                const SizedBox(height: 40),
              ]),
            ),
          ),

          if (!_hasInternet)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                child: Column(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.wifi_off, size: 48, color: kPrimaryRed),
                  SizedBox(height: 12),
                  Text('لا يوجد اتصال بالإنترنت', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('الرجاء التحقق من الشبكة'),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------
  // Helpers & small widgets
  // ---------------------

  Widget _offerCard(SpecialOffer offer, String imageUrl) {
    final img = imageUrl;
    final name = offer.name ?? 'عرض خاص';
    final desc = offer.offer_type ?? offer.new_price ?? '';
    final itemId = offer.item_Id ?? '';
    final possibleItem = _itemsById[itemId];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          if (possibleItem != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: possibleItem, user: widget.user)));
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            img.isNotEmpty ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover)) : Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.5), Colors.transparent]))),
            Positioned(left: 12, right: 12, bottom: 12, child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  if (possibleItem != null) {
                    if (possibleItem.isSoldOut) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠ هذه القطعة نفدت الكمية')));
                      return;
                    }
                    await _addToCart(possibleItem);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إضافة هذا العرض للسلة')));
                  }
                },
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('أضف للسلة', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryRed, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), minimumSize: const Size(60, 36)),
              ),
            ])),
          ]),
        ),
      ),
    );
  }

  PageController _page_controllerSafe() => _pageController;
}