//order.dart
class Order {
  final int orderId;
  final String address;
  final String paymentMethod;
  final double total;
  final DateTime orderDate;
  final List<OrderItem> items;

  Order({
    required this.orderId,
    required this.address,
    required this.paymentMethod,
    required this.total,
    required this.orderDate,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    orderId: json['order_id'],
    address: json['address'],
    paymentMethod: json['payment_method'],
    total: double.parse(json['total'].toString()),
    orderDate: DateTime.parse(json['order_date']),
    items: (json['items'] as List)
        .map((j) => OrderItem.fromJson(j))
        .toList(),
  );
}

class OrderItem {
  final String name;
  final double price;
  final int quantity;
  final String unit;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    name: json['item_name'],
    price: double.parse(json['price'].toString()),
    quantity: json['quantity'],
    unit: json['unit'],
  );
}
