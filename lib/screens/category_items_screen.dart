// lib/screens/all_categories_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/user.dart';
import 'category_items_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final snap = await _firestore.collection('categories').get();
      final cats = snap.docs.map((d) => Category.fromFirestore(d.data() as Map<String, dynamic>, d.id)).toList();
      setState(() => _categories = cats);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جميع التصنيفات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? const Center(child: Text('لا توجد تصنيفات'))
          : GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final c = _categories[i];
          return GestureDetector(
            onTap: () {
              // هنا نعيد نفس التوجيه كما في HomeScreen — يتوقع user لذلك نرسل user ضيف (id=0)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => category_items_screen(
                    user: const User(id: 0, name: '', phone: '', email: '', profileImage: '', balance: 0.0),
                    categoryId: c.id,
                    categoryName: c.name,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // عرض الصورة مباشرة عبر NetworkImage؛ لو تريد نفس الـ cache استخدم CachedNetworkImage
                  Image.network(
                    c.image ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset('assets/aqlanassets.jpg', fit: BoxFit.cover),
                  ),
                  Container(color: Colors.black.withOpacity(0.25)),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        c.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
