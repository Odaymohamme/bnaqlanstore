// lib/screens/cart_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/image_cashe_manager.dart';
import 'confirm_order_screen.dart';

class CartScreen extends StatefulWidget {
  final User user;
  const CartScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() => _loading = true);
    try {
      // نرسل customerId كسلسلة لأن الحقل في Firestore مخزن كـ string
      _items = await ApiService.fetchCart(widget.user.id.toString());
    } catch (e) {
      debugPrint('❌ fetchCart error: $e');
      _items = [];
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalPrice => _items.fold(0.0, (sum, it) {
    final p = double.tryParse(it.price) ?? 0.0;
    final q = int.tryParse(it.quantity) ?? 1;
    return sum + p * q;
  });

  Future<void> _updateQuantity(CartItem item, int newQty) async {
    if (newQty < 1) return;

    final success = await ApiService.updateCartItemQuantity(
      cartId: item.cartId,
      quantity: newQty.toString(),
    );

    if (success) {
      setState(() {
        final idx = _items.indexWhere((e) => e.cartId == item.cartId);
        if (idx != -1) {
          _items[idx] = CartItem(
            cartId: item.cartId,
            customerId: item.customerId,
            itemId: item.itemId,
            itemName: item.itemName,
            price: item.price,
            quantity: newQty.toString(),
            unit: item.unit,
            customDescription: item.customDescription,
            imageUrl: item.imageUrl,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل تحديث الكمية')));
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final success = await ApiService.removeCartItem(cartId: item.cartId);
    if (success) {
      setState(() {
        _items.removeWhere((e) => e.cartId == item.cartId);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف العنصر من السلة')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل حذف العنصر')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلة التسوق')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('سلة التسوق فارغة'))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];

                // imageUrl يجب أن يكون رابطاً كاملاً (تم تصحيحه في fetchCart)
                final imageUrl = item.imageUrl.isNotEmpty
                    ? item.imageUrl
                    : ''; // خالية -> سيعرض الصورة الافتراضية في errorWidget

                final currentQty = int.tryParse(item.quantity) ?? 1;
                final priceDouble = double.tryParse(item.price) ?? 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        cacheManager: MyImageCacheManager.instance, // استخدم الكاش مانيجر المركزي
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/aqlanassets.jpg',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Image.asset(
                        'assets/aqlanassets.jpg',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),

                    title: Text(
                      item.itemName.isEmpty ? 'بدون اسم' : item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity} × ${item.price} ر.س لكل ${item.unit}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: currentQty > 1
                                  ? () => _updateQuantity(
                                  item, currentQty - 1)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Text(item.quantity),
                            IconButton(
                              onPressed: () =>
                                  _updateQuantity(item, currentQty + 1),
                              icon: const Icon(Icons.add),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _removeItem(item),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${(priceDouble * currentQty).toStringAsFixed(2)} ر.س',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي: ${_totalPrice.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConfirmOrderScreen(
                          user: widget.user,
                          cartItems: _items,
                          total: _totalPrice,
                        ),
                      ),
                    ).then((value) {
                      // بعد العودة من شاشة الاعتماد نعيد تحميل السلة
                      _loadCart();
                    });
                  },
                  child: const Text('الدفع'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
