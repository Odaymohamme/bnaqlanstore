import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/unit.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ProductDetail extends StatefulWidget {
  final Item item;
  final User user;

  const ProductDetail({
    Key? key,
    required this.item,
    required this.user,
  }) : super(key: key);

  @override
  State<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  List<Unit> _units = [];
  Unit? _selectedUnit;
  int _qty = 1;

  bool _loading = true;
  bool _adding = false;

  late double _itemPrice;

  @override
  void initState() {
    super.initState();
    _itemPrice = _parseDouble(widget.item.price);
    _fetchUnits();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<void> _fetchUnits() async {
    final units = await ApiService.fetchItemUnits(widget.item.id);

    if (!mounted) return;
    setState(() {
      _units = units;
      _selectedUnit = null;
      _loading = false;
    });
  }

  double get _currentPrice {
    if (_selectedUnit != null) return _selectedUnit!.price;
    return _itemPrice;
  }

  String get _currentUnit {
    if (_selectedUnit != null) return _selectedUnit!.name;
    return "حبة";
  }

  Future<void> _addToCart() async {
    if (widget.item.isSoldOut) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا الصنف غير متوفر حالياً')));
      }
      return;
    }

    setState(() => _adding = true);

    final ok = await ApiService.addToCartFromDetail(
      customerId: widget.user.id,
      itemId: int.tryParse(widget.item.id) ?? widget.item.idInt,
      itemName: widget.item.name,
      price: _currentPrice,
      quantity: _qty,
      unit: _currentUnit,
    );

    setState(() => _adding = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? "تمت الإضافة للسلة ✅" : "فشل الإضافة ❌")),
    );
  }

  @override
  Widget build(BuildContext context) {
    String imgUrl = "";
    if (widget.item.imageUrl.startsWith("http")) {
      imgUrl = widget.item.imageUrl;
    } else {
      imgUrl =
      "https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/products/${widget.item.imageUrl}";
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imgUrl,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 240,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, size: 60),
                    ),
                  ),
                ),
                if (widget.item.isSoldOut)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      child: const Text('نفدت الكمية !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            Text(widget.item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

            const SizedBox(height: 10),

            Text(widget.item.description, style: const TextStyle(fontSize: 15, color: Colors.black87)),

            const SizedBox(height: 20),

            Text("السعر: ${_currentPrice.toStringAsFixed(2)} ر.س", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 20),

            if (_units.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("اختر الوحدة:", style: TextStyle(fontSize: 16)),
                  DropdownButton<Unit>(
                    value: _selectedUnit,
                    hint: const Text("الوحدة الافتراضية (من سعر المنتج)"),
                    isExpanded: true,
                    items: _units.map((u) {
                      return DropdownMenuItem<Unit>(
                        value: u,
                        child: Text("${u.name} - ${u.price.toStringAsFixed(2)} ر.س"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedUnit = val);
                    },
                  ),
                ],
              ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Text("الكمية:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                ),
                Text("$_qty", style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _qty++),
                ),
              ],
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (widget.item.isSoldOut || _adding) ? null : _addToCart,
                child: _adding
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.item.isSoldOut ? "نفدت الكمية" : "إضافة إلى السلة"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}