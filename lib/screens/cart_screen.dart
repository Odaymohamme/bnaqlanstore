// lib/screens/cart_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
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
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      _items = await ApiService.fetchCart(widget.user.id);
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  double get _totalPrice =>
      _items.fold(0.0, (sum, it) => sum + it.price * it.quantity);

  Future<void> _updateQuantity(CartItem item, int newQty) async {
    final success = await ApiService.updateCartItemQuantity(
      customerId: widget.user.id,
      itemId: item.id,
      unit: item.unit,
      quantity: newQty,
    );
    if (success) {
      setState(() {
        final index = _items.indexOf(item);
        if (index != -1) {
          _items[index] = CartItem(
            id: item.id,
            name: item.name,
            imageUrl: item.imageUrl,
            price: item.price,
            quantity: newQty,
            unit: item.unit,
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث الكمية')),
      );
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final success = await ApiService.removeCartItem(
      customerId: widget.user.id,
      itemId: item.id,
      unit: item.unit,
    );
    if (success) {
      setState(() {
        _items.remove(item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العنصر من السلة')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حذف العنصر')),
      );
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
                    final item = _items[i]; // ✅ المتغيّر الصحيح
                    final networkImage = item.imageUrl.isEmpty
                        ? null
                        : '${Constants.baseUrl}/uploads/${item.imageUrl}';
                    print("Item in cart: ${item.name}");

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const CircularProgressIndicator(),
                              errorWidget: (_, __, ___) => Image.asset(
                                  'assets/aqlanassets.jpg',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  ),
                              ),
                        ),

                        // ✅ اسم الصنف هنا
                        title: Text(
                          item.name.isEmpty ? 'بدون اسم' : item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,

                          ),
                        ),

                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.quantity} × ${item.price.toStringAsFixed(2)} ر.س لكل ${item.unit}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: item.quantity > 1
                                      ? () => _updateQuantity(
                                      item, item.quantity - 1)
                                      : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(item.quantity.toString()),
                                IconButton(
                                  onPressed: () => _updateQuantity(
                                      item, item.quantity + 1),
                                  icon: const Icon(Icons.add),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _removeItem(item),
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),

                        trailing: Text(
                          '${(item.price * item.quantity).toStringAsFixed(2)} ر.س',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
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
                        );
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