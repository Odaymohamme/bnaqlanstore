// lib/models/special_offer.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialOffer {
  final String id; // document id في Firestore
  final String? item_Id;     // اسم الحقل كما في القاعدة (المطلوب في كودك)
  final String? new_price;   // سعر العرض الجديد (كنص كما وصفت)
  final String? old_price;   // السعر القديم إن كان موجودًا
  final String? offer_type;  // نوع العرض
  final String? name;        // اسم العرض أو اسم المنتج (اختياري)
  final String? image;       // رابط/اسم الصورة إن وُجد داخل العرض
  final String? categoryId;  // حقل الصنف إن وُجد
  final Timestamp? createdAt;

  SpecialOffer({
    required this.id,
    this.item_Id,
    this.new_price,
    this.old_price,
    this.offer_type,
    this.name,
    this.image,
    this.categoryId,
    this.createdAt,
  });

  /// قراءة من Firestore document snapshot أو Map
  factory SpecialOffer.fromFirestore(Map<String, dynamic> data, String docId) {
    // نحاول قراءة الحقول بعدة أسماء شائعة
    String? read(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) return m[k].toString();
      }
      return null;
    }

    final created = data['created_at'] is Timestamp ? data['created_at'] as Timestamp : null;

    return SpecialOffer(
      id: docId,
      item_Id: read(data, ['item_Id', 'item_id', 'itemId', 'itemIdStr']),
      new_price: read(data, ['new_price', 'newPrice', 'price_new', 'newprice']),
      old_price: read(data, ['old_price', 'oldPrice', 'price_old']),
      offer_type: read(data, ['offer_type', 'offerType', 'type']),
      name: read(data, ['name', 'title', 'offer_name']),
      image: read(data, ['image', 'imageUrl', 'photo', 'img']),
      categoryId: read(data, ['categoryId', 'category_id', 'category']),
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_Id': item_Id,
      'new_price': new_price,
      'old_price': old_price,
      'offer_type': offer_type,
      'name': name,
      'image': image,
      'categoryId': categoryId,
      'created_at': createdAt,
    };
  }
}
