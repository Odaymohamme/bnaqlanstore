class Item {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String categoryId;
  final String price; // نحافظ عليه كسلسلة نصية كما في Firestore

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.categoryId,
    required this.price,
  });

  // ✅ التحويل من Firestore (تصحيح أسماء الحقول)
  factory Item.fromFirestore(Map<String, dynamic> data, String docId) {
    return Item(
      id: data['item_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: data['image_url']?.toString() ?? '', // ✅ تم تصحيح الاسم هنا
      categoryId: data['category_id']?.toString() ?? '', // ✅ كذلك هنا
      price: data['price']?.toString() ?? '0.0',
    );
  }

  // ✅ التحويل من JSON
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      price: json['price']?.toString() ?? '0.0',
    );
  }

  // ✅ التحويل إلى JSON (للتخزين في Firestore)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'category_id': categoryId,
      'price': price,
    };
  }

  // ✅ لتحويل السعر إلى رقم
  double get priceValue {
    return double.tryParse(price.replaceAll(',', '.')) ?? 0.0;
  }

  int get idInt => int.tryParse(id)??0;
}