import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../screens/product_detail.dart';

class RecommendedSection extends StatefulWidget {
  final User user;

  const RecommendedSection({super.key, required this.user});

  @override
  State<RecommendedSection> createState() => _RecommendedSectionState();
}

class _RecommendedSectionState extends State<RecommendedSection> {
  List<Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommended();
  }

  Future<void> _loadRecommended() async {
    final list = await ApiService.fetchRecommendedItems(widget.user.id);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const SizedBox();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          "اقتراحات لك",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 12),

      SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (_, i) {
            final it = _items[i];

            return InkWell(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProductDetail(item: it, user: widget.user)));
              },
              child: SizedBox(
                width: 150,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          it.imageUrl,
                          height: 120,
                          width: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[300], height: 120),
                        ),
                      ),
                      if (it.isSoldOut)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                                color: Colors.red, borderRadius: BorderRadius.circular(6)),
                            child: const Text('نفدت الكمية !',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(it.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${it.priceValue.toStringAsFixed(2)} ر.س",
                      style: const TextStyle(color: Colors.green)),
                ]),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemCount: _items.length,
        ),
      ),
    ]);
  }
}