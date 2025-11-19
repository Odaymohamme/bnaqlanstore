// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/user.dart';
import '../models/category.dart';
import '../models/special_offer.dart';
import '../models/item.dart';
import '../utils/constants.dart';
import '../models/cart_item.dart';
import '../models/unit.dart';
import '../models/order.dart';
import '../models/address.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/image_cashe_manager.dart';
import '../utils/image_cashe_manager.dart';
import 'dart:convert';



class ApiService {

  static final _firestore = FirebaseFirestore.instance;
  static void someMethod() {
    debugPrint('رسالة ديباج لعرض الخطأ أو البيانات');
  }

  // تسجيل دخول عميل
  // تسجيل الدخول
  static Future<User> loginClient(String phone, String password) async {
    try {
      // 🔍 البحث عن المستخدم من مجموعة العملاء
      final query = await _firestore
          .collection('customers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception("رقم الهاتف غير مسجل");
      }

      final doc = query.docs.first;
      final data = doc.data();

      // ✅ تحقق من كلمة المرور
      if (data['password'] != password) {
        throw Exception("كلمة المرور غير صحيحة");
      }

      // 🧩 تجهيز البيانات بالشكل الذي يتوقعه الموديل User
      final jsonData = {
        'customer_id': doc.id, // id = document id
        'name': data['name'] ?? '',
        'phone': data['phone'] ?? '',
        'email': data['email'] ?? '',
        'profile_image': data['profile_image'] ?? '',
        'balance': data['balance'] ?? 0,
      };

      // 🔁 استخدام الـ fromJson الموجودة مسبقًا
      return User.fromJson(jsonData);
    } catch (e) {
      print("Firestore login error: $e");
      throw Exception("فشل تسجيل الدخول: $e");
    }
    }

  static Future<bool> registerClient({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${Constants.baseUrl}/endpoints/register_client.php');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    return data['success']==true;
  }

  /// تسجيل دخول (جاهزة عندك غالباً)
  /*static Future<User> loginClient(String phone, String password) async {
    final uri = Uri.parse('${Constants.baseUrl}/endpoints/login_client.php');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    if (resp.statusCode != 200) {
      throw Exception('فشل الاتصال بالسيرفر');
    }

    final data = jsonDecode(resp.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'فشل تسجيل الدخول');
    }

    return User.fromJson(data['data']);
    }*/

  // 🔹 جلب التصنيفات من Firestore
  static Future<List<Category>> fetchCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs
        .map((doc) => Category.fromFirestore(doc.data(), doc.id))
        .toList();
  }


  // 🔹 جلب العروض الخاصة من Firestore
  static Future<List<SpecialOffer>> fetchSpecialOffers() async {
    final snapshot = await _firestore.collection('special_offers').get();
    return snapshot.docs
        .map((doc) => SpecialOffer.fromFirestore(doc.data(), doc.id))
        .toList();
  }
  // 🔹 جلب كل المنتجات من Firestore
  static Future<List<Item>> fetchItems() async {
    final snapshot = await _firestore.collection('items').get();
    return snapshot.docs
        .map((doc) => Item.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // lib/services/api_service.dart
// بعد fetchItems…
  /// 🔹 جلب المنتجات حسب التصنيف من Firestore
  static Future<List<Item>> fetchItemsByCategory(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('items')
          .where('categoryId', isEqualTo: categoryId)
          .get();

      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("🔥 Firestore fetchItemsByCategory error: $e");
      return[];
    }
    }


  /*static Future<String?> uploadProfileImage(int userId, File imageFile) async {
    final url = Uri.parse(
        '${Constants.baseUrl}/endpoints/upload_profile_image.php');
    final req = http.MultipartRequest('POST', url)
      ..fields['user_id'] = userId.toString()
      ..files.add(await http.MultipartFile.fromPath(
        'profile_image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      final data = jsonDecode(body);
      if (data['success'] == true && data['filename'] != null) {
        return data['filename'];
      }
    }
    return null;
  }*/

  static Future<bool> updateCartItemQuantity({
    required String cartId,
    required String  quantity,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection("cart").doc(cartId);
      await docRef.update({"quantity": quantity});
      return true;
    } catch (e) {
      debugPrint("updateCartItemQuantity failed: $e");
      return false;
    }
  }


  /////
  static Future<List<Item>> fetchRecommendedItems(int customerId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // 1. جلب كل الطلبات الخاصة بالمستخدم
      final ordersSnap = await firestore
          .collection("orders")
          .where("customer_id", isEqualTo: customerId.toString())
          .get();

      if (ordersSnap.docs.isEmpty) return [];

      // 2. جمع order_id
      final orderIds = ordersSnap.docs
          .map((e) => e["order_id"].toString())
          .toList();

      if (orderIds.isEmpty) return [];

      // 3. جلب جميع order_items التابعة للطلبات
      final orderItemsSnap = await firestore
          .collection("order_items")
          .where("order_id", whereIn: orderIds.take(10).toList())
          .get();

      if (orderItemsSnap.docs.isEmpty) return [];

      // 4. جمع اسماء الأصناف التي اشتراها المستخدم
      final purchasedNames = orderItemsSnap.docs
          .map((e) => e["item_name"]?.toString() ?? "")
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (purchasedNames.isEmpty) return [];

      // 5. جلب جميع الأصناف في items
      final allItemsSnap = await firestore.collection("items").get();

      // 6. البحث عن التصنيفات عبر الاسم وليس item_id
      Set<String> categories = {};

      for (var doc in allItemsSnap.docs) {
        final data = doc.data();
        final itemName = data["name"]?.toString() ?? "";

        if (purchasedNames.contains(itemName)) {
          final cat = data["category_id"]?.toString() ?? "";
          if (cat.isNotEmpty) categories.add(cat);
        }
      }

      if (categories.isEmpty) return [];

      // 7. جلب الأصناف المشابهة من نفس التصنيفات
      List<Item> recommended = [];

      for (final cat in categories) {
        final catSnap = await firestore
            .collection("items")
            .where("category_id", isEqualTo: cat)
            .get();

        recommended.addAll(
          catSnap.docs.map(
                (doc) => Item.fromFirestore(doc.data(), doc.id),
          ),
        );
      }

      // 8. خلط النتائج مثل أمازون و Noon
      recommended.shuffle();

      // 9. إعادة النتائج (حد أقصى 20 صنف)
      return recommended.take(20).toList();
    } catch (e) {
      debugPrint("🔥 fetchRecommendedItems error: $e");
      return [];
    }
  }

  static Future<bool> removeCartItem({
    required String cartId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection("cart").doc(cartId).delete();
      return true;
    } catch (e) {
      debugPrint("removeCartItem failed: $e");
      return false;
    }
  }


  static Future<bool> addToCart({
    required int customerId,
    required String itemId,
    required String itemName,
    required String price,
    required int quantity,
    String unit = "",
    String customDescription = "",
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // إنشاء معرف فريد للسلة
      final docRef = firestore.collection('cart').doc();

      await docRef.set({
        'cart_id': docRef.id,
        'customer_id': customerId.toString(),
        'item_id': itemId,
        'item_name': itemName,
        'price': price,
        'quantity': quantity.toString(),
        'unit': unit,
        'custom_description': customDescription,
      });

      return true;
    } catch (e) {
      debugPrint("❌ addToCart Firestore error: $e");
      return false;
    }
  }


  // ✅ جلب السلة من Firestore
// ✅ جلب السلة من Firestore
  static Future<List<CartItem>> fetchCart(String customerId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final snap = await firestore
          .collection("cart")
          .where("customer_id", isEqualTo: customerId)
          .get();

      List<CartItem> items = [];

      for (var doc in snap.docs) {
        final data = doc.data();

        final String cartId = data['cart_id']?.toString() ?? doc.id;
        final String itemId = data['item_id']?.toString() ?? "";
        final String itemNameFromCart = data['item_name']?.toString() ?? "";
        final String price = data['price']?.toString() ?? "0";
        final String quantity = data['quantity']?.toString() ?? "1";
        final String unit = data['unit']?.toString() ?? "";
        final String customDescription = data['custom_description']?.toString() ?? "";

        // احصل على قيمة الصورة الخام من مستندات items أو من مستند السلة كـ fallback
        String rawImage = "";

        if (itemId.isNotEmpty) {
          try {
            // 1) جرّب الوصول كمستند إذا كان itemId هو doc id
            final docById = await firestore.collection('items').doc(itemId).get();
            if (docById.exists) {
              final itemData = docById.data();
              rawImage = itemData?['image_url']?.toString() ??
                  itemData?['image']?.toString() ??
                  itemData?['imageUrl']?.toString() ??
                  "";
            } else {
              // 2) إن لم توجد وثيقة بالـ doc id، نفذ استعلام حسب الحقل item_id
              final query = await firestore
                  .collection('items')
                  .where('item_id', isEqualTo: itemId)
                  .limit(1)
                  .get();
              if (query.docs.isNotEmpty) {
                final itemData = query.docs.first.data();
                rawImage = itemData['image_url']?.toString() ??
                    itemData['image']?.toString() ??
                    itemData['imageUrl']?.toString() ??
                    "";
              } else {
                // لا يوجد doc في items مطابق — ربما الصورة مخزنة في مستند السلة نفسه
                rawImage = data['image_url']?.toString() ?? data['image']?.toString() ?? "";
              }
            }
          } catch (err) {
            // في حالة أي خطأ أثناء الوصول إلى مجموعة items، نستخدم fallback من السلة
            debugPrint("warning: unable to fetch item doc for itemId=$itemId -> $err");
            rawImage = data['image_url']?.toString() ?? data['image']?.toString() ?? "";
          }
        } else {
          // لا itemId — خذ الصورة من مستند السلة إن وُجدت
          rawImage = data['image_url']?.toString() ?? data['image']?.toString() ?? "";
        }

        // الآن نحول الـ rawImage إلى رابط صالح بنفس منطق home/search
        final resolved = MyImageCacheManager.resolveProductImageUrl(rawImage);

        // طباعة تصحيحية صغيرة لترى الرابط فعليًا في console أثناء التشغيل
        debugPrint("fetchCart: cartId=$cartId itemId=$itemId imageResolved=$resolved");

        items.add(CartItem(
          cartId: cartId,
          customerId: customerId,
          itemId: itemId,
          itemName: itemNameFromCart,
          price: price,
          quantity: quantity,
          unit: unit,
          customDescription: customDescription,
          imageUrl: resolved,
        ));
      }

      return items;
    } catch (e, st) {
      debugPrint("❌ fetchCart error: $e");
      debugPrint("$st");
      return [];
    }
  }






  /// 🔹 جلب الوحدات الخاصة بالصنف
  static Future<List<Unit>> fetchItemUnits(String itemId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("item_units")
          .where("item_id", isEqualTo: itemId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Unit(
          id: 0,
          name: data['unit_name']?.toString() ?? "حبة",
          price: double.tryParse(data['unit_price']?.toString() ?? '0') ?? 0.0,
        );
      }).toList();
    } catch (e) {
      print("Firestore fetchItemUnits error: $e");
      return [];
    }
  }

  static Future<bool> confirmOrder({
    required int customerId,
    required String address,
    required String paymentMethod,
    required double total,
    required List<Map<String, dynamic>> items,
    File? proofImage,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1) إنشاء doc جديد للأمر للحصول على orderId
      final orderDoc = firestore.collection("orders").doc();
      final orderId = orderDoc.id;

      // ----------------------------------------------------------
      // 2) رفع إثبات الدفع إلى Supabase (إن وُجد)
      // ----------------------------------------------------------
      String proofUrl = "";

      if (paymentMethod == "بطاقة" && proofImage != null) {
        final fileName = "$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg";

        final supabasePublicUrl =
            "https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/payment_proofs/$fileName";

        final uploadUrl = Uri.parse(
            "https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/payment_proofs/$fileName");

        final bytes = await proofImage.readAsBytes();

        final resp = await http.post(
          uploadUrl,
          headers: {
            "Content-Type": "application/octet-stream",
            "Authorization": "Bearer YOUR_SUPABASE_SERVICE_ROLE_KEY",
          },
          body: bytes,
        );

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          proofUrl = supabasePublicUrl;
        } else {
          debugPrint("❌ Upload to Supabase failed: ${resp.statusCode} ${resp.body}");
        }
      }

      // ----------------------------------------------------------
      // 3) حفظ الطلب في مجموعة orders مع الحقول المطلوبة
      // ----------------------------------------------------------
      final orderData = {
        "accepted_at": "",
        "address": address,
        "customer_id": customerId.toString(),
        "order_date": FieldValue.serverTimestamp(),
        "order_id": orderId,
        "payment_method": paymentMethod,
        "payment_proof": proofUrl,
        "status": "pending",
        "total": total,
        "created_at": FieldValue.serverTimestamp(),
      };

      await orderDoc.set(orderData);

      // ----------------------------------------------------------
      // 4) حفظ كل عنصر في مجموعة order_items
      // ----------------------------------------------------------
      final batch = firestore.batch();
      final orderItemsCollection = firestore.collection("order_items");

      for (final it in items) {
        final map = <String, dynamic>{
          "custom_description": it["custom_description"] ?? "",
          "custom_image": it["custom_image"] ?? "",
          "custom_name": it["custom_name"] ?? "",
          "id": it["id"]?.toString() ?? "",
          "item_id": it["item_id"]?.toString() ?? "",
          "item_name": it["item_name"] ?? "",
          "order_id": orderId,
          "price": it["price"]?.toString() ?? "",
          "quantity": it["quantity"]?.toString() ?? "",
          "unit": it["unit"] ?? "",
          "created_at": FieldValue.serverTimestamp(),
        };

        final docRef = orderItemsCollection.doc();
        batch.set(docRef, map);
      }

      await batch.commit();

      // ----------------------------------------------------------
      // 5) حذف عناصر السلة بعد اعتماد الطلب
      // ----------------------------------------------------------
      final cartSnap = await firestore
          .collection("cart")
          .where("customer_id", isEqualTo: customerId.toString())
          .get();

      final cartBatch = firestore.batch();
      for (var doc in cartSnap.docs) {
        cartBatch.delete(doc.reference);
      }
      await cartBatch.commit();

      return true;
    } catch (e, st) {
      debugPrint("confirmOrder failed: $e");
      debugPrint("$st");
      return false;
    }
  }

  /// جلب الطلبات السابقة
  static Future<List<Order>> fetchOrders(int customerId) async {
    final url = Uri.parse('${Constants
        .baseUrl}/endpoints/fetch_orders.php?customer_id=$customerId');
    final resp = await http.get(url);
    final data = jsonDecode(resp.body);
    if (data['success'] != true) return [];
    return (data['data'] as List).map((j) => Order.fromJson(j)).toList();
  }

  // جلب العناوين
  static Future<List<Address>> fetchAddresses(int customerId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final snap = await firestore
          .collection("addresses")
          .where("customer_id", isEqualTo: customerId.toString())
          .get();

      return snap.docs.map((doc) {
        return Address.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      debugPrint("❌ fetchAddresses error: $e");
      return [];
    }
  }

// إضافة عنوان جديد
  static Future<bool> addAddress({
    required int customerId,
    required String label,
    required String address,
    String? mapLink,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection("addresses").add({
        "customer_id": customerId.toString(),
        "label": label,
        "address": address,
        "map_link": mapLink ?? "",
        "created_at": FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint("❌ addAddress error: $e");
      return false;
    }
  }


  /////رففع الصور حق السداد

  static Future<String?> uploadProofToSupabase(File image) async {
    try {
      final bytes = await image.readAsBytes();
      final fileName = "proof_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final url =
          "https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/order_proofs/$fileName";

      final req = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "image/jpeg"},
        body: bytes,
      );

      if (req.statusCode == 200 || req.statusCode == 201) {
        return url;
      }

      return null;
    } catch (e) {
      debugPrint("❌ uploadProofToSupabase: $e");
      return null;
    }
  }
  /// أضف صنف للمفضلة
  static Future<bool> addFavorite(int customerId, int itemId) async {
    final url = Uri.parse('${Constants.baseUrl}/endpoints/add_favorite.php');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customer_id': customerId,
        'item_id': itemId,
      }),
    );
    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }

  /// إزالة صنف من المفضلة
  static Future<bool> removeFavorite(int customerId, int itemId) async {
    final url = Uri.parse('${Constants.baseUrl}/endpoints/remove_favorite.php');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customer_id': customerId,
        'item_id': itemId,
      }),
    );
    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }

  // ✅ جلب المفضلة
  // ✅ جلب المفضلة من Firestore
  static Future<List<Item>> fetchFavorites(String customerId) async {
    final snapshot = await _firestore
        .collection('favorites')
        .doc(customerId)
        .collection('items')
        .get();

    return snapshot.docs
        .map((doc) => Item.fromFirestore(doc.data(), doc.id))
    .toList();
  }

  /// أداة مساعدة للتعامل مع أي HTML زائد قبل/بعد JSON (لو ظهر تحذير)
  static Map<String, dynamic> _safeJsonObject(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      final start = body.indexOf('{');
      final end = body.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final trimmed = body.substring(start, end + 1);
        return jsonDecode(trimmed) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// جلب بيانات الملف الشخصي
  static Future<User> fetchProfile(int userId) async {
    final url = Uri.parse(
        '${Constants.baseUrl}/endpoints/get_profile.php?customer_id=$userId');
    final resp = await http.get(url);
    final data = _safeJsonObject(resp.body);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'خطأ في جلب الملف الشخصي');
    }
    return User.fromJson(data['data']);
  }

  /// تحديث بيانات الملف الشخصي (بدون تشفير كلمة المرور حسب طلبك)
  static Future<bool> updateProfile({
    required int customerId,
    required String name,
    required String email,
    String? password,
    File? profileImage,
    bool deleteImage = false, // ✅ أضفنا هذا
  }) async {
    final uri = Uri.parse('${Constants.baseUrl}/endpoints/update_profile.php');
    final request = http.MultipartRequest('POST', uri);

    request.fields['customer_id'] = customerId.toString();
    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['deleteImage'] = deleteImage ? '1' : '0'; // ✅ نرسله للسيرفر

    if (password != null) {
      request.fields['password'] = password;
    }

    if (profileImage != null && !deleteImage) {
      request.files.add(await http.MultipartFile.fromPath(
        'profile_image',
        profileImage.path,
      ));
    }

    final res = await request.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) return false;
    final data = jsonDecode(body);
    return data['success']==true;
  }
  /// (اختياري) رفع صورة البروفايل لوحدها — لأن الـ Drawer الحالي يستخدمه
  static Future<String?> uploadProfileImage(int customerId, File file) async {
    final uri = Uri.parse(
        '${Constants.baseUrl}/endpoints/upload_profile_image.php');
    final req = http.MultipartRequest('POST', uri)
      ..fields['customer_id'] = customerId.toString()
      ..files.add(await http.MultipartFile.fromPath(
        'profile_image',
        file.path,
        contentType: MediaType('image', file.path.split('.').last),
      ));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    final data = _safeJsonObject(body);

    if (data['success'] == true) {
      return data['filename'] as String?;
    }
    return null;
    }
  // ✅ جلب المشتريات الأخيرة من Firestore
  static Future<List<Item>> fetchRecentPurchasedItems(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('purchased')
          .doc(customerId)
          .collection('items')
          .orderBy('purchaseDate', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Firestore error (recent items): $e');
      return[];
    }
  }

  /// 🔹 إضافة صنف للسلة في Firestore
  static Future<bool> addToCartFromDetail({
    required int customerId,
    required int itemId,
    required String itemName,
    required double price,
    required int quantity,
    required String unit,
  }) async {
    try {
      final cartRef = _firestore.collection('cart');
      final docId = '${customerId}${itemId}$unit';

      final doc = await cartRef.doc(docId).get();

      if (doc.exists) {
        // ✅ تحديث الكمية الحالية
        final currentQty = int.tryParse(doc['quantity'] ?? '0') ?? 0;
        await cartRef.doc(docId).update({
          'quantity': (currentQty + quantity).toString(),
          'price': price.toString(),
        });
      } else {
        // ✅ إضافة جديدة
        await cartRef.doc(docId).set({
          'customer_id': customerId.toString(),
          'item_id': itemId.toString(),
          'item_name': itemName,
          'price': price.toString(),
          'quantity': quantity.toString(),
          'unit': unit,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      print('Firestore addToCartFromDetail error: $e');
      return false;
    }
    }
  /////كود اضافف العرض الى السلة
  // داخل ApiService
  static Future<bool> addOfferToCart({
    required int customerId,
    required int itemId,
    required int quantity,
    required double price,
    required String name,
    required String image, // يرسل للخادم لكن الخادم لا يخزنه (لا عمود بالصورة في cart)
  }) async {
    final uri = Uri.parse('${Constants.baseUrl}/endpoints/add_offer_to_cart.php');
    final resp = await http.post(
      uri,
      body: {
        'customer_id': customerId.toString(),
        'item_id': itemId.toString(),
        'quantity': quantity.toString(),
        'price': price.toString(),
        'name': name,
        'image': image, // اختيارية عند الخادم
      },
    );

    debugPrint('addOfferToCart status: ${resp.statusCode}');
    debugPrint('addOfferToCart body: ${resp.body}');

    if (resp.statusCode != 200) return false;

    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data['success'] == true) return true;
      debugPrint('❌ addOfferToCart server message: ${data['message']}');
      return false;
    } catch (e) {
      debugPrint('❌ addOfferToCart parse error: $e');
      return false;
    }
  }


  /// إرسال OTP (يخزّن على الخادم ويُرسل عبر WhatsApp/Twilio إذا مُهيأ)
  static Future<bool> sendOtp({
    required int customerId,
    required String phone,
  }) async {
    final url = Uri.parse('${Constants.baseUrl}/endpoints/send_otp.php');
    final resp = await http.post(url, body: {
      'customer_id': customerId.toString(),
      'phone': phone,
    });

    debugPrint('sendOtp status: ${resp.statusCode}');
    debugPrint('sendOtp body: ${resp.body}');

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }

  /// التحقق من الـ OTP
  static Future<bool> verifyOtp({
    required int customerId,
    required String otp,
  }) async {
    final uri = Uri.parse('${Constants.baseUrl}/endpoints/verify_otp.php');
    final resp = await http.post(uri, body: {
      'customer_id': customerId.toString(),
      'otp': otp,
    });

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    return data['success']==true;
  }

  /// 🔍 البحث عن الأصناف من Firestore
  static Future<List<Item>> searchItems(String query) async {
    try {
      QuerySnapshot snapshot;

      if (query.isEmpty) {
        // جلب جميع العناصر عند فتح البحث بدون إدخال
        snapshot = await _firestore.collection('items').get();
      } else {
        // جلب العناصر التي تحتوي على النص في الاسم (بحث جزئي)
        snapshot = await _firestore
            .collection('items')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .get();
      }

      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print("Firestore search error: $e");
      return [];
    }
    }

  static Future<Map<String, dynamic>?> fetchStoreInfo() async {
    final uri = Uri.parse('${Constants.baseUrl}/endpoints/fetch_store.php');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception("فشل الاتصال بالسيرفر");
    }

    final data = jsonDecode(resp.body);
    if (data['success'] != true) return null;
    return data['data'];
  }
}

String fixSupabaseImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';

  // رابـط موقع Signed من Supabase
  if (url.contains('/object/sign/')) {
    final match = RegExp(r'/products/[^/]+\.jpg').firstMatch(url);
    if (match != null) {
      final path = match.group(0)!;
      return 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public$path';
    }
  }

  return url;
}
