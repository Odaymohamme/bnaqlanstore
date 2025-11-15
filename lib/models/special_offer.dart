class SpecialOffer {
  final String id;
  final String name;
  final String image;
  final String itemId;
  final String description;
  final double oldPrice;
  final double newPrice;
  final String categoryId;

  SpecialOffer({
    required this.id,
    required this.name,
    required this.image,
    required this.itemId,
    required this.description,
    required this.oldPrice,
    required this.newPrice,
    required this.categoryId,
  });

  factory SpecialOffer.fromFirestore(Map<String, dynamic> data, String id) {
    return SpecialOffer(
        id: id,
        name: data['name'] ?? '',
        image: data['image'] ?? '',
        itemId: data['itemId'] ?? '',
        description: data['description'] ?? '',
        oldPrice: double.tryParse(data['oldPrice'] ?? '0') ?? 0.0,
        newPrice: double.tryParse(data['newPrice'] ?? '0') ?? 0.0,
        categoryId: data['categoryId'] ?? '',
        );
    }
}