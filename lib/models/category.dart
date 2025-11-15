class Category {
  final String id;
  final String name;
  final String imageUrl;

  Category({required this.id, required this.name, required this.imageUrl});

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
        id: id,
        name: data['name'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        );
    }
}