// lib/models/cart_item.dart
class CartItem {
  final int id;
  final String name;
  final String imageUrl;
  final double price;
  final int quantity;
  final String unit;

  CartItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
        id: json['cart_id'] ?? json['item_id'] ?? 0,
        name: json['item_name']?.toString() ?? '', // ✅ التصحيح هنا
        imageUrl: json['image']?.toString() ?? '',
        price: double.tryParse(json['price'].toString()) ?? 0.0,
        quantity: int.tryParse(json['quantity'].toString()) ?? 1,
        unit: json['unit']?.toString() ?? '',
        );
    }
}