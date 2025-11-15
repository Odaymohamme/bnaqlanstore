// lib/models/cart_item.dart
class CartItem {
  final String cartId;       // cart_id في Firestore (string)
  final String customerId;   // customer_id (string)
  final String itemId;       // item_id (string)
  final String itemName;     // item_name
  final String price;        // price كـ string في Firestore
  final String quantity;     // quantity كـ string
  final String unit;         // unit
  final String customDescription; // custom_description
  final String imageUrl;     // رابط الصورة النهائي (تمت معالجته)

  CartItem({
    required this.cartId,
    required this.customerId,
    required this.itemId,
    required this.itemName,
    required this.price,
    required this.quantity,
    required this.unit,
    this.customDescription = "",
    this.imageUrl = "",
  });

  Map<String, dynamic> toJson() => {
    'cart_id': cartId,
    'customer_id': customerId,
    'item_id': itemId,
    'item_name': itemName,
    'price': price,
    'quantity': quantity,
    'unit': unit,
    'custom_description': customDescription,
    'image_url': imageUrl,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartId: json['cart_id']?.toString() ?? "",
      customerId: json['customer_id']?.toString() ?? "",
      itemId: json['item_id']?.toString() ?? "",
      itemName: json['item_name']?.toString() ?? "",
      price: json['price']?.toString() ?? "0",
      quantity: json['quantity']?.toString() ?? "1",
      unit: json['unit']?.toString() ?? "",
      customDescription: json['custom_description']?.toString() ?? "",
      imageUrl: json['image_url']?.toString() ?? "",
    );
  }
}
