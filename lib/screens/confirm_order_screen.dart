// lib/screens/confirm_order_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'add_address_screen.dart';
import '../screens/home_screen.dart';

class ConfirmOrderScreen extends StatefulWidget {
  final User user;
  final List<CartItem> cartItems;
  final double total;

  const ConfirmOrderScreen({
    Key? key,
    required this.user,
    required this.cartItems,
    required this.total,
  }) : super(key: key);

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  // Address dropdown
  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _loadingAddresses = true;

  // Payment method & proof
  String _paymentMethod = 'نقداً';
  File? _proofImage;
  final ImagePicker _picker = ImagePicker();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final list = await ApiService.fetchAddresses(widget.user.id);
    setState(() {
      _addresses = list;
      _loadingAddresses = false;
      if (_addresses.isNotEmpty) {
        _selectedAddress = _addresses.first;
      }
    });
  }

  /// دالة لالتقاط الصورة من المعرض
  Future<void> _pickProof() async {
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _proofImage = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر عنواناً')),
      );
      return;
    }
    if (_paymentMethod == 'بطاقة' && _proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ارفع إثبات الدفع')),
      );
      return;
    }

    setState(() => _submitting = true);

    // نحول كل عنصر من cartItems إلى JSON (يشمل الحقول الأساسية فقط)
    final itemsJson = widget.cartItems.map((it) => it.toJson()).toList();

    final ok = await ApiService.confirmOrder(
      customerId: widget.user.id,
      address: _selectedAddress!.address,
      paymentMethod: _paymentMethod,
      total: widget.total,
      items: itemsJson,
      proofImage: _paymentMethod == 'بطاقة' ? _proofImage : null,
    );

    setState(() => _submitting = false);

    if (ok) {
      // عرض حوار تأكيد
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('تم إرسال الطلب'),
          content: const Text(
              'تم إرسال الطلب بنجاح، سيتم اعتماده وإرساله لك في أقرب وقت ممكن.'),
          actions: [
            TextButton(
              onPressed: () {
                // عد إلى الرئيسية
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => HomeScreen(user: widget.user)),
                      (route) => false,
                );
              },
              child: const Text('العودة للرئيسية'),
            ),
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل الاعتماد')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('اعتماد الطلب')),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Address selector
                _loadingAddresses
                    ? const CircularProgressIndicator()
                    : Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Address>(
                        value: _selectedAddress,
                        items: _addresses
                            .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.label),
                        ))
                            .toList(),
                        onChanged: (a) =>
                            setState(() => _selectedAddress = a),
                        decoration: const InputDecoration(
                          labelText: 'اختر عنوان التوصيل',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add_location),
                      label: const Text('عنوان جديد'),
                      onPressed: () async {
                        final added = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddAddressScreen(user: widget.user),
                          ),
                        );
                        if (added == true) _loadAddresses();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Payment method selector
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: ['نقداً', 'بطاقة']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                ),

                // Proof upload (عند اختيار بطاقة)
                if (_paymentMethod == 'بطاقة') ...[
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'رفع إثبات الدفع',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickProof,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _proofImage == null
                          ? const Center(
                        child: Text('اضغط لرفع صورة البطاقة'),
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                        Image.file(_proofImage!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Total display
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'الإجمالي: ${widget.total.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const Spacer(),

                // زرّ الاعتماد
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('اعتمد الطلب'),
                  ),
                ),
              ],
            ),
            ),
        );
    }
}
