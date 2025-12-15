import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

  class OrdersHistoryScreen extends StatefulWidget {
  final String customerId;

  const OrdersHistoryScreen({Key? key, required this.customerId})
      : super(key: key);

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final snap = await _firestore
          .collection('orders')
          .where('customer_id', isEqualTo: widget.customerId)
          .orderBy('order_date', descending: true)
          .get();

      _orders = snap.docs;
    } catch (e) {
      debugPrint("خطأ في تحميل الطلبات: $e");
    }

    setState(() => _loading = false);
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      return DateFormat('yyyy/MM/dd - hh:mm a').format(ts.toDate());
    }
    return ts.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'pending':
        return 'قيد المراجعة';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي السابقة'),
        backgroundColor: Colors.red[700],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('لا توجد طلبات سابقة'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index].data();

          final orderId = order['order_id'] ?? '';
          final address = order['address'] ?? '';
          final status = order['status'] ?? '';
          final total = order['total'] ?? '0';
          final payMethod = order['payment_method'] ?? '';
          final orderDate = order['order_date'];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(
                      firestoreOrderId: _orders[index].id,
                      orderId: orderId.toString(),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// رقم الطلب
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'طلب رقم: $orderId',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusText(status),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text('العنوان: $address'),
                    const SizedBox(height: 4),
                    Text('التاريخ: ${_formatTimestamp(orderDate)}'),
                    const SizedBox(height: 4),
                    Text('الدفع: $payMethod'),

                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'الإجمالي: $total ريال',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/////////////////////////////////////////////////////////
/// شاشة تفاصيل الطلب + عناصر order_items
/////////////////////////////////////////////////////////

class OrderDetailsScreen extends StatefulWidget {
  final String firestoreOrderId;
  final String orderId;

  const OrderDetailsScreen({
    Key? key,
    required this.firestoreOrderId,
    required this.orderId,
  }) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final snap = await _firestore
          .collection('order_items')
          .where('order_id', isEqualTo: widget.firestoreOrderId)
          .get();

      _items = snap.docs;
    } catch (e) {
      debugPrint('خطأ في تحميل عناصر الطلب: $e');
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${widget.orderId}'),
        backgroundColor: Colors.red[700],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('لا توجد عناصر لهذا الطلب'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index].data();

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: Text(item['item_name'] ?? ''),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الكمية: ${item['quantity']} ${item['unit']}'),
                  Text('السعر: ${item['price']} ريال'),
                  if ((item['custom_name'] ?? '').toString().isNotEmpty)
                    Text('اسم مخصص: ${item['custom_name']}'),
                  if ((item['custom_description'] ?? '').toString().isNotEmpty)
                    Text('ملاحظة: ${item['custom_description']}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
