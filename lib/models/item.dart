class Item {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String categoryId;
  final String price; // نحافظ عليه كسلسلة نصية كما في Firestore
  final String status; // يمكن أن يكون 'active' أو 'inactive' أو غيره
  final String statusId; // بعض المشاريع تستخدم status_id مثل "0" أو "1"

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.categoryId,
    required this.price,
    this.status = '',
    this.statusId = '',
  });

  // التحويل من Firestore (دعم حقلي status و status_id)
  factory Item.fromFirestore(Map<String, dynamic> data, String docId) {
    return Item(
      id: (data['item_id'] ?? data['id'] ?? docId).toString(),
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: (data['image_url'] ?? data['image'] ?? '').toString(),
      categoryId: (data['category_id'] ?? data['category'] ?? '').toString(),
      price: data['price']?.toString() ?? '0.0',
      status: data['status']?.toString() ?? '',
      statusId: data['status_id']?.toString() ?? data['statusId']?.toString() ?? '',
    );
  }

  // التحويل من JSON
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      price: json['price']?.toString() ?? '0.0',
      status: json['status']?.toString() ?? '',
      statusId: json['status_id']?.toString() ?? json['statusId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'category_id': categoryId,
      'price': price,
      'status': status,
      'status_id': statusId,
    };
  }

  double get priceValue {
    return double.tryParse(price.replaceAll(',', '.')) ?? 0.0;
  }

  int get idInt => int.tryParse(id) ?? 0;

  // هل الصنف نفدت كميته / غير متاح؟ (حسب طلبك: status == 'inactive' أو status_id == '0')
  bool get isSoldOut {
    final s = status.trim().toLowerCase();
    final sid = statusId.trim();
    return s == 'inactive' || sid == '0' || s == '0';
  }
}