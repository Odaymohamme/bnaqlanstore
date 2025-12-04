// lib/screens/category_items_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/user.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../screens/product_detail.dart';

class CategoryItemsScreen extends StatefulWidget {
  final User? user;
  final String? categoryId;
  final String? categoryName;

  const CategoryItemsScreen({
    Key? key,
    this.user,
    this.categoryId,
    this.categoryName,
  }) : super(key: key);

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  List<Category> _categories = [];
  List<Item> _items = [];
  final Set<String> _addingToCartIds = {};

  // id التصنيف المحدد حاليا بواسطة الشريط العلوي
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // نحمّل التصنيفات دائمًا لأننا سنعرض الشريط العلوي
    await _loadCategories();

    // إذا جاؤنا مع categoryId من الهوم (أو من أي مكان)، نحدده ونحمّل أصنافه
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      _selectedCategoryId = widget.categoryId;
      await _loadItemsForCategory(widget.categoryId!);
    } else {
      // لا نحمّل الأصناف افتراضياً — المستخدم سيختار من الشريط أو سنعرض كل التصنيفات
      _items = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await _firestore.collection('categories').get();
      final cats = snap.docs
          .map((d) => Category.fromFirestore(d.data() as Map<String, dynamic>, d.id))
          .toList();
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) setState(() => _categories = []);
    }
  }

  // نسخة شاملة لتحميل الأصناف كما ناقشنا سابقاً
  Future<void> _loadItemsForCategory(String catId) async {
    try {
      List<QueryDocumentSnapshot> docs = [];

      // محاولة 1: categoryId
      try {
        final q = await _firestore.collection('items').where('categoryId', isEqualTo: catId).get();
        if (q.docs.isNotEmpty) docs = q.docs;
      } catch (_) {}

      // محاولة 2: category_id
      if (docs.isEmpty) {
        try {
          final q = await _firestore.collection('items').where('category_id', isEqualTo: catId).get();
          if (q.docs.isNotEmpty) docs = q.docs;
        } catch (_) {}
      }

      // محاولة 3: category as DocumentReference
      if (docs.isEmpty) {
        try {
          final catRef = _firestore.collection('categories').doc(catId);
          final q = await _firestore.collection('items').where('category', isEqualTo: catRef).get();
          if (q.docs.isNotEmpty) docs = q.docs;
        } catch (_) {}
      }

      // fallback: جلب الكل وفلترة محليًا
      if (docs.isEmpty) {
        final all = await _firestore.collection('items').get();
        final filtered = all.docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final cand1 = (m['categoryId'] ?? m['category_id'] ?? '').toString();
          if (cand1 == catId) return true;

          final dynamic possibleRef = m['category'];
          if (possibleRef != null) {
            try {
              if (possibleRef is DocumentReference) {
                if (possibleRef.id == catId) return true;
              } else if (possibleRef is Map && possibleRef['id'] != null) {
                if (possibleRef['id'].toString() == catId) return true;
              } else {
                if (possibleRef.toString() == catId) return true;
              }
            } catch (_) {}
          }

          for (final f in ['category_ref', 'categoryIdRef', 'categoryId_ref', 'categoryId_value']) {
            final v = (m[f] ?? '').toString();
            if (v == catId) return true;
          }

          if (d.id == catId) return true;

          return false;
        }).toList();

        final items = filtered.map((d) => Item.fromFirestore(d.data() as Map<String, dynamic>, d.id)).toList();
        if (mounted) setState(() => _items = items);
        return;
      }

      final items = docs.map((d) => Item.fromFirestore(d.data() as Map<String, dynamic>, d.id)).toList();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('Error loading items for category $catId: $e');
      if (mounted) setState(() => _items = []);
    }
  }

  String _categoryImageUrl(Category c) {
    final url = (c.image.isNotEmpty) ? c.image : (c.imageUrl.isNotEmpty ? c.imageUrl : '');
    return url;
  }

  // شريط التصنيفات العلوي كقوائم دائرية - متجاوب
  Widget _buildTopCategoryScroller() {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;

      // 1) حساب Avatar الأساسي
      final avatarSize = (maxWidth * 0.12).clamp(44.0, 84.0);

      // 2) إعدادات البادينغ العمودي داخل ListView (نستخدم نفس القيم عمليًا)
      const double listViewVerticalPadding = 8.0; // أعلى وأسفل في ListView
      const double spacingBetweenAvatarAndLabel = 6.0; // المسافة بين الصورة والنص

      // 3) ارتفاع النص المحجوز
      final labelHeight = (avatarSize * 0.22).clamp(14.0, 22.0);

      // 4) توقع أعلى حدود وpadding عند الحالة المحددة (selected)
      const double maxBorderWidth = 3.0;
      const double maxInnerPadding = 3.0;

      // 5) outerSize يحوي avatar + حدود + padding
      final outerSize = (avatarSize + (maxBorderWidth * 2) + (maxInnerPadding * 2)).ceilToDouble();

      // 6) نحسب totalHeight بدقة: padding top + avatar outer + gap + label + padding bottom + هامش أمان
      final double totalHeight = (listViewVerticalPadding /* top */ +
          outerSize +
          spacingBetweenAvatarAndLabel +
          labelHeight +
          listViewVerticalPadding /* bottom */ +
          4.0 /* safety margin */)
          .ceilToDouble();

      // safety: لا تسمح لأن يكون totalHeight أقل من قيمة دنيا
      final minAllowed = 88.0;
      final finalHeight = totalHeight < minAllowed ? minAllowed : totalHeight;

      return SizedBox(
        height: finalHeight,
        child: ClipRect(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: listViewVerticalPadding),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = _categories[i];
              final imageUrl = _categoryImageUrl(c);
              final bool selected = _selectedCategoryId != null && _selectedCategoryId == c.id;

              // عند الاختيار نستخدم border و padding فعليين
              final double borderW = selected ? 3.0 : 0.0;
              final double pad = selected ? 2.5 : 1.0;

              // itemOuterSize تُضمن ألا تتجاوز outerSize
              final double innerAvatar = avatarSize;
              final double itemOuterSize = (innerAvatar + (borderW * 2) + (pad * 2)).clamp(innerAvatar, outerSize);

              return InkWell(
                onTap: () async {
                  setState(() {
                    _selectedCategoryId = c.id;
                    _loading = true;
                  });
                  await _loadItemsForCategory(c.id);
                  if (mounted) setState(() => _loading = false);
                },
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: (outerSize * 1.15).clamp(80.0, 140.0), // عرض افتراضي لكل عنصر مع بعض المساحة
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // مهم جداً
                    children: [
                      // صندوق ثابت بالحجم الخارجي حتى لا يتغير عند التحديد
                      SizedBox(
                        width: outerSize,
                        height: outerSize,
                        child: Center(
                          child: Container(
                            width: itemOuterSize,
                            height: itemOuterSize,
                            padding: EdgeInsets.all(pad),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: borderW > 0 ? Border.all(color: Colors.orangeAccent, width: borderW) : null,
                              boxShadow: selected ? [BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 1)] : null,
                            ),
                            child: CircleAvatar(
                              radius: innerAvatar / 2,
                              backgroundColor: Colors.grey[200],
                              child: ClipOval(
                                child: SizedBox(
                                  width: innerAvatar,
                                  height: innerAvatar,
                                  child: imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                                    errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                                  )
                                      : Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: spacingBetweenAvatarAndLabel),

                      // قيد النص: نمنع تأثير تكبير الخط عن طريق ضبط textScaleFactor محليًا
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: outerSize * 0.95,
                          maxHeight: labelHeight,
                        ),
                        child: Center(
                          child: MediaQuery(
                            // نجبر textScaleFactor ألا يتجاوز 1.0 داخل هذا النص
                            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                c.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: (avatarSize * 0.18).clamp(10.0, 14.0),
                                  color: selected ? Colors.orangeAccent : Colors.black87,
                                ),
                              ),
                            ),
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
      );
    });
  }



  Widget _buildCategoryCard(Category c) {
    final imageUrl = _categoryImageUrl(c);

    return GestureDetector(
      onTap: () {
        final userToSend = widget.user ?? User(id: 0, name: '', phone: '', email: '', profileImage: '', balance: 0.0);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryItemsScreen(
              user: userToSend,
              // الآن نمرّر document id لضمان تطابق الربط في items
              categoryId: c.id,
              categoryName: c.name,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[200]),
                errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
              )
            else
              Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
            Container(color: Colors.black.withOpacity(0.28)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  c.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItemToCartFirestore(Item it, {int quantity = 1, String unit = 'حبة'}) async {
    final customerId = (widget.user?.id ?? 0).toString();
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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تمت إضافة ${it.name} إلى السلة')),
      );
    } catch (e) {
      debugPrint('Add to cart error in CategoryItemsScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ فشل إضافة ${it.name} إلى السلة')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToCartIds.remove(itemId));
    }
  }

  Widget _buildItemCard(Item it) {
    final imageUrl = (it.imageUrl ?? '').toString();

    return GestureDetector(
      onTap: () {
        final userToSend = widget.user ?? User(id: 0, name: '', phone: '', email: '', profileImage: '', balance: 0.0);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: it, user: userToSend)));
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: (imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                )
                    : Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
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
                    final userToSend = widget.user ?? User(id: 0, name: '', phone: '', email: '', profileImage: '', balance: 0.0);
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: it, user: userToSend)));
                  },
                  child: _addingToCartIds.contains(it.id)
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("إضافة إلى السلة", style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadCategories();
    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      await _loadItemsForCategory(_selectedCategoryId!);
    } else if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      await _loadItemsForCategory(widget.categoryId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingCategories = (widget.categoryId == null || widget.categoryId!.isEmpty) && (_selectedCategoryId == null);

    return Scaffold(
      appBar: AppBar(
        title: Text(showingCategories ? 'التصنيفات' : (widget.categoryName ?? 'أصناف')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            // شريط دائري للتنقل السريع بين التصنيفات (يتكيّف مع أحجام الشاشات)
            if (_categories.isNotEmpty) _buildTopCategoryScroller(),
            // المحتوى: إما عرض كل التصنيفات أو عرض الأصناف المختارة
            Expanded(
              child: showingCategories ? _buildCategoriesView() : _buildItemsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesView() {
    if (_categories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد تصنيفات')),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        itemCount: _categories.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: MediaQuery.of(context).size.width / 2 - 18, // متكيف مع العرض
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemBuilder: (context, i) {
          final c = _categories[i];
          return _buildCategoryCard(c);
        },
      ),
    );
  }

  Widget _buildItemsView() {
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text('لا توجد منتجات في هذا التصنيف')),
        ],
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // نحدد maxCrossAxisExtent بحيث يتغير عدد الأعمدة حسب عرض الشاشة
    final maxExtent = (screenWidth / 2).clamp(160.0, 320.0);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        itemCount: _items.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, i) {
          final it = _items[i];
          return _buildItemCard(it);
        },
      ),
    );
  }
}
