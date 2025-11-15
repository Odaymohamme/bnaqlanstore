// lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  final User user;
  const OrdersScreen({Key? key, required this.user}) : super(key: key);

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final list = await ApiService.fetchOrders(widget.user.id);
    setState(() {
      _orders = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات السابقة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('لا توجد طلبات سابقة'))
          : ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (ctx, i) {
          final o = _orders[i];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ExpansionTile(
              title: Text('طلب #${o.orderId}  -  إجمالي ${o.total.toStringAsFixed(2)} ر.س'),
              subtitle: Text(o.orderDate.toString()),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('العنوان: ${o.address}\nالدفع: ${o.paymentMethod}'),
                ),
                ...o.items.map((it) => ListTile(
                  title: Text(it.name),
                  subtitle: Text('${it.quantity} ${it.unit} × ${it.price} ر.س'),
                  trailing: Text((it.quantity * it.price).toStringAsFixed(2)),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}
