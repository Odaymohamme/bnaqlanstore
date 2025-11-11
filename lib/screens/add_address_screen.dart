// lib/screens/add_address_screen.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/address.dart';
import '../services/api_service.dart';

class AddAddressScreen extends StatefulWidget {
  final User user;
  const AddAddressScreen({Key? key, required this.user}) : super(key: key);

  @override
  _AddAddressScreenState createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _labelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mapLinkCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingAddresses = true;
  List<Address> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final res = await ApiService.fetchAddresses(widget.user.id);
      if (mounted) setState(() => _addresses = res);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحميل العناوين السابقة')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _submit() async {
    if (_labelCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء كافة الحقول')),
      );
      return;
    }
    setState(() => _submitting = true);
    final ok = await ApiService.addAddress(
      customerId: widget.user.id,
      label: _labelCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      mapLink: _mapLinkCtrl.text.trim().isEmpty ? null : _mapLinkCtrl.text.trim(),
    );
    setState(() => _submitting = false);
    if (ok) {
      _labelCtrl.clear();
      _addressCtrl.clear();
      _mapLinkCtrl.clear();
      await _loadAddresses(); // تحديث القائمة مباشرة
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إضافة العنوان بنجاح')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ فشل إضافة العنوان')),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
        appBar: AppBar(title: const Text('إضافة عنوان جديد')),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: 'اسم العنوان (مثلاً: المنزل)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'العنوان الكامل'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mapLinkCtrl,
                decoration: const InputDecoration(labelText: 'رابط الخريطة (اختياري)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ العنوان'),
                ),
              ),
              const Divider(height: 30),
              const Align(
                alignment: Alignment.centerRight,
                child: Text("📍 العناوين السابقة:", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loadingAddresses
                    ? const Center(child: CircularProgressIndicator())
                    : _addresses.isEmpty
                    ? const Center(child: Text("لا توجد عناوين محفوظة"))
                    : ListView.builder(
                  itemCount: _addresses.length,
                  itemBuilder: (ctx, i) {
                    final addr = _addresses[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.blue),
                        title: Text(addr.label),
                        subtitle: Text(addr.address),
                        trailing: addr.mapLink != null && addr.mapLink!.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.map, color: Colors.green),
                          onPressed: () {
                            // تفتح الرابط في المتصفح
                            // يمكن استخدام url_launcher هنا
                          },
                        )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ]),
            ),
        );
    }
}