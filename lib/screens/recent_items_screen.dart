// lib/screens/recent_items_screen.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'product_detail.dart';

class RecentItemsScreen extends StatefulWidget {
  final User user;
  const RecentItemsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<RecentItemsScreen> createState() => _RecentItemsScreenState();
}

class _RecentItemsScreenState extends State<RecentItemsScreen> {
  List<Item> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await ApiService.fetchRecentPurchasedItems(widget.user.id.toString());
    } catch (e) {
      debugPrint('خطأ في جلب البيانات: $e');
      _error = 'فشل تحميل البيانات';
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('المشتريات الأخيرة')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _items.isEmpty
            ? const Center(child: Text('لا توجد مشتريات حديثة'))
            : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final it = _items[i];

              // 🔹 بناء رابط الصورة من Supabase (حقل imageUrl يخزن اسم الملف فقط)
              final imageUrl = '${Constants.supabaseUrl}/storage/v1/object/public/items/${it.imageUrl}';

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetail(item: it, user: widget.user),
                  ),
                ),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, _) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, _, __) => const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${it.price} ر.س',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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