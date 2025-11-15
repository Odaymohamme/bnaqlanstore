//unit.dart
class Unit {
  final int id;
  final String name;
  final double price;

  Unit({required this.id, required this.name, required this.price});

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
    id: json['id'],
    name: json['name'],
    price: double.parse(json['price'].toString()),
  );
}
