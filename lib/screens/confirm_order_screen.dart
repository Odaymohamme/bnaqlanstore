// lib/screens/confirm_order_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../utils/constants.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  List<Address> _addresses = [];
  Address? _selectedAddress;
  bool _loadingAddresses = true;

  String _paymentMethod = 'نقداً';
  File? _proofFileMobile;
  Uint8List? _proofBytesWeb;
  String? _proofFileName;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final list = await ApiService.fetchAddresses(widget.user.id);
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _loadingAddresses = false;
        _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
      });
    } catch (e, st) {
      debugPrint('ConfirmOrderScreen._loadAddresses error: $e\n$st');
      if (mounted) {
        setState(() => _loadingAddresses = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('فشل تحميل العناوين')));
      }
    }
  }

  Future<void> _pickProof() async {
    try {
      final XFile? picked =
      await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      _proofFileName = picked.name;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _proofBytesWeb = bytes;
          _proofFileMobile = null;
        });
      } else {
        setState(() {
          _proofFileMobile = File(picked.path);
          _proofBytesWeb = null;
        });
      }
    } catch (e) {
      debugPrint('pickProof error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل اختيار الصورة')));
    }
  }

  // رفع إثبات الدفع إلى Supabase
  Future<String?> _uploadProofToSupabase(String orderId) async {
    final bucket = 'payment_proofs';
    final fileName =
        _proofFileName ?? 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$orderId-$fileName';

    if (!kIsWeb && _proofFileMobile != null) {
      try {
        final storage = supabase.Supabase.instance.client.storage;

        await storage.from(bucket).upload(
          path,
          _proofFileMobile!,
          fileOptions: const supabase.FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

        return '${Constants.supabaseUrl}/storage/v1/object/public/$bucket/$path';
      } catch (e, st) {
        debugPrint('Supabase client upload (mobile) failed: $e\n$st');
      }
    }

    try {
      const supabaseUrl = 'https://nrjwzdkhwcqokwlmkzem.supabase.co';
      const anonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yand6ZGtod2Nxb2t3bG1remVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MTkzMjYsImV4cCI6MjA3NjI5NTMyNn0.1c8usW_rodQEo0s2G8S5Ggc2NN8iOU0GO0Qd6yFAm8g';

      final uploadUrl = Uri.parse('$supabaseUrl/storage/v1/object/$bucket/$path');

      List<int> bytes;
      if (kIsWeb && _proofBytesWeb != null) {
        bytes = _proofBytesWeb!.toList();
      } else if (!kIsWeb && _proofFileMobile != null) {
        bytes = await _proofFileMobile!.readAsBytes();
      } else {
        debugPrint('No proof data available for fallback upload');
        return null;
      }

      final resp = await http.put(
        uploadUrl,
        headers: {
          'Authorization': 'Bearer $anonKey',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      debugPrint('Supabase fallback: ${resp.statusCode} body: ${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return '$supabaseUrl/storage/v1/object/public/$bucket/$path';
      }

      return null;
    } catch (e, st) {
      debugPrint('Supabase fallback upload error: $e\n$st');
      return null;
    }
  }

  // إرسال إشعار للـ Admin عند طلب جديد
  Future<void> sendOrderNotificationToAdmin(String orderId) async {
    try {
      // افترض أن الـ FCM Tokens مخزنة في مجموعة "fcm_tokens" في Firestore
      final tokensSnap = await _firestore.collection('fcm_tokens').get();
      final tokens = tokensSnap.docs.map((d) => d.id).toList();

      for (var token in tokens) {
        await FirebaseMessaging.instance.sendMessage(
          to: token,
          data: {
            'title': 'طلب جديد',
            'body': 'تم تقديم طلب جديد برقم: $orderId',
          },
        );
      }
    } catch (e) {
      debugPrint('sendOrderNotificationToAdmin error: $e');
    }
  }

  Future<bool> _submitOrder() async {
    try {
      if (_selectedAddress == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('اختر عنواناً')));
        return false;
      }
      if (_paymentMethod != 'نقداً' &&
          _proofFileMobile == null &&
          _proofBytesWeb == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ارفع إثبات الدفع')));
        return false;
      }

      setState(() => _submitting = true);

      final orderDoc = _firestore.collection('orders').doc();
      final orderId = orderDoc.id;

      String proofUrl = '';
      if (_paymentMethod != 'نقداً' &&
          (_proofFileMobile != null || _proofBytesWeb != null)) {
        final uploaded = await _uploadProofToSupabase(orderId);
        if (uploaded != null) {
          proofUrl = uploaded;
        } else {
          setState(() => _submitting = false);
          final cont = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('فشل رفع الصورة'),
              content: const Text(
                  'فشل رفع إثبات الدفع. هل تريد متابعة الطلب بدون إثبات أم إلغاء؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(_, false),
                    child: const Text('إلغاء')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(_, true),
                    child: const Text('المتابعة بدون إثبات')),
              ],
            ),
          );
          if (cont != true) return false;
        }
      }

      final orderData = {
        "accepted_at": "",
        "address": _selectedAddress!.address,
        "address_label": _selectedAddress!.label,
        "customer_id": widget.user.id.toString(),
        "order_date": FieldValue.serverTimestamp(),
        "order_id": orderId,
        "payment_method": _paymentMethod,
        "payment_proof": proofUrl,
        "status": "pending",
        "total": widget.total,
        "created_at": FieldValue.serverTimestamp(),
      };

      await orderDoc.set(orderData);

      // إضافة الأصناف
      final batch = _firestore.batch();
      for (var it in widget.cartItems) {
        final itemDoc = _firestore.collection('order_items').doc();
        batch.set(itemDoc, {
          'order_id': orderId,
          'item_id': it.itemId,
          'item_name': it.itemName,
          'price': it.price,
          'quantity': it.quantity,
          'unit': it.unit,
          'custom_description': it.customDescription,
          'image_url': it.imageUrl,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // حذف السلة
      try {
        final cartSnap = await _firestore
            .collection('cart')
            .where('customer_id', isEqualTo: widget.user.id.toString())
            .get();
        final cartBatch = _firestore.batch();
        for (var d in cartSnap.docs) cartBatch.delete(d.reference);
        await cartBatch.commit();
      } catch (_) {}

      // إرسال إشعار للـ Admin
      await sendOrderNotificationToAdmin(orderId);

      setState(() => _submitting = false);
      return true;
    } catch (e, st) {
      debugPrint('submitOrder error: $e\n$st');
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('فشل حفظ الطلب')));
      return false;
    }
  }

  Future<void> _onSubmitPressed() async {
    final ok = await _submitOrder();
    if (ok) {
      if (!mounted) return;
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
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => HomeScreen(user: widget.user)),
                        (route) => false);
              },
              child: const Text('العودة للرئيسية'),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('حسناً')),
          ],
        ),
      );
    }
  }

  Widget _proofPreview() {
    if (_proofBytesWeb != null) return Image.memory(_proofBytesWeb!, fit: BoxFit.cover);
    if (_proofFileMobile != null) return Image.file(_proofFileMobile!, fit: BoxFit.cover);
    return const Center(child: Text('اضغط لرفع صورة إثبات الدفع'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اعتماد الطلب')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _loadingAddresses
              ? const CircularProgressIndicator()
              : Row(children: [
            Expanded(
              child: DropdownButtonFormField<Address>(
                value: _selectedAddress,
                items: _addresses
                    .map((a) => DropdownMenuItem(value: a, child: Text(a.label)))
                    .toList(),
                onChanged: (a) => setState(() => _selectedAddress = a),
                decoration: const InputDecoration(
                    labelText: 'اختر عنوان التوصيل', border: OutlineInputBorder()),
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
                        builder: (_) => AddAddressScreen(user: widget.user)));
                if (added == true) {
                  await _loadAddresses();
                  if (_addresses.isNotEmpty)
                    setState(() => _selectedAddress = _addresses.first);
                }
              },
            ),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            items: ['نقداً', 'بطاقة', 'حوالة']
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'نقداً'),
            decoration: const InputDecoration(
                labelText: 'طريقة الدفع', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (_paymentMethod != 'نقداً') ...[
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('رفع إثبات الدفع', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickProof,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8)),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _proofPreview()),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Align(
              alignment: Alignment.centerLeft,
              child: Text('الإجمالي: ${widget.total.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _onSubmitPressed,
              child: _submitting
                  ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('اعتمد الطلب'),
            ),
          ),
        ]),
      ),
    );
  }
}
