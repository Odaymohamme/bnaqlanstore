class   Category {
  final String id;            // ID الوثيقة في Firestore
  final String categoryId;    // category_id من قاعدة البيانات
  final String name;
  final String description;
  final String image;         // الصورة الرئيسية

  Category({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.image,
  });

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      categoryId: data['category_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      image: data['image']?.toString() ?? '',   // <-- هذا الحقل الموجود في Firestore
    );
  }

  // Getter إضافي إن كنت تريد التوافق مع كودك القديم
  String get imageUrl => image;    // حتى لو الكود القديم يستخدم imageUrl لا تحدث مشكلة
}
