// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import 'product_detail.dart';

class SearchScreen extends StatefulWidget {
  final User user;
  const SearchScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Item> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAllItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllItems() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.searchItems("");
      if (mounted) setState(() => _results = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("⚠ خطأ أثناء جلب البيانات: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doSearch() async {
    final query = _searchCtrl.text.trim();
    setState(() => _loading = true);
    try {
      final res = await ApiService.searchItems(query);
      if (mounted) setState(() => _results = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("⚠ خطأ أثناء البحث: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("البحث عن صنف")),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: "ابحث عن صنف...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _doSearch, child: const Text("بحث"))
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _results.isEmpty
              ? const Center(child: Text("🔍 لم يتم العثور على أصناف"))
              : ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final it = _results[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Stack(
                    children: [
                      it.imageUrl.isNotEmpty
                          ? Image.network(it.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
                      if (it.isSoldOut)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: Colors.red,
                            child: const Text('نفدت الكمية !', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                  title: Text(it.name),
                  subtitle: Text(it.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text("${it.price} ر.س", style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(item: it, user: widget.user)));
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}