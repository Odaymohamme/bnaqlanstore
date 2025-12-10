import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// شاشة العروض المحدثة
// التغييرات الأساسية:
// 1) تجنب استدعاء .doc(itemId) عندما يكون itemId فارغًا -> كان يسبب الخطأ: "A document path must be a non-empty string".
// 2) استخدم استعلام where للبحث عن الصنف بحقل item_id داخل مجموعة items (هذا يتوافق مع هيكلة قاعدة البيانات في صورك).
// 3) استخدم حقل الصورة image_url (كما هو واضح في سكرينشوت قاعدة البيانات).
// 4) حالات عرض محسنة للصور والحقول المفقودة.

class OffersScreen extends StatefulWidget {
  const OffersScreen({Key? key}) : super(key: key);

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض الخاصة'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('special_offers')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('خطأ: \${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final offersDocs = snapshot.data?.docs ?? [];
          if (offersDocs.isEmpty) return const Center(child: Text('لا توجد عروض حالياً'));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: offersDocs.length,
            itemBuilder: (context, index) {
              final offer = offersDocs[index].data();
              final itemId = (offer['item_id'] ?? '').toString().trim();
              final newPrice = (offer['new_price'] ?? '').toString();
              final oldPrice = (offer['old_price'] ?? '').toString();
              final offerType = (offer['offer_type'] ?? '').toString();

              // إذا كان itemId فارغًا -> نعرض بطاقة توضح أن الصنف غير معرف
              if (itemId.isEmpty) {
                return OfferCard.missingItem(
                  itemId: 'غير معرف',
                  newPrice: newPrice,
                  oldPrice: oldPrice,
                  offerType: offerType,
                );
              }

              // نستعلم عن الصنف باستخدام where('item_id', isEqualTo: itemId).limit(1)
              return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: _firestore
                    .collection('items')
                    .where('item_id', isEqualTo: itemId)
                    .limit(1)
                    .get(),
                builder: (context, itemSnapshot) {
                  if (itemSnapshot.hasError) {
                    return ListTile(
                      title: Text('خطأ بجلب بيانات الصنف: \$itemId'),
                      subtitle: Text(itemSnapshot.error.toString()),
                    );
                  }

                  if (itemSnapshot.connectionState == ConnectionState.waiting) {
                    return OfferCard.loading(
                      newPrice: newPrice,
                      oldPrice: oldPrice,
                      offerType: offerType,
                    );
                  }

                  if (!itemSnapshot.hasData || itemSnapshot.data!.docs.isEmpty) {
                    // لم نجد مستند مطابق لحقل item_id
                    return OfferCard.missingItem(
                      itemId: itemId,
                      newPrice: newPrice,
                      oldPrice: oldPrice,
                      offerType: offerType,
                    );
                  }

                  final itemDoc = itemSnapshot.data!.docs.first.data();

                  // حقول الصنف كما في سكرينشوت: name, description (او details), image_url, price, status
                  final itemName = (itemDoc['name'] ?? 'اسم غير معروف').toString();
                  final itemDetails = (itemDoc['description'] ?? itemDoc['details'] ?? '').toString();

                  // صورة قد تكون في image_url أو image
                  String? imageUrl;
                  if (itemDoc.containsKey('image_url') && itemDoc['image_url'] != null) {
                    imageUrl = itemDoc['image_url'].toString();
                  } else if (itemDoc.containsKey('image') && itemDoc['image'] != null) {
                    imageUrl = itemDoc['image'].toString();
                  } else if (itemDoc.containsKey('images') && itemDoc['images'] is List && (itemDoc['images'] as List).isNotEmpty) {
                    imageUrl = (itemDoc['images'] as List).first.toString();
                  }

                  return OfferCard(
                    itemId: itemId,
                    itemName: itemName,
                    itemDetails: itemDetails,
                    imageUrl: imageUrl,
                    newPrice: newPrice,
                    oldPrice: oldPrice,
                    offerType: offerType,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- بطاقة عرض واحدة ---
class OfferCard extends StatelessWidget {
  final String? itemId;
  final String? itemName;
  final String? itemDetails;
  final String? imageUrl;
  final String newPrice;
  final String oldPrice;
  final String offerType;
  final bool isLoading;
  final bool itemMissing;

  const OfferCard({
    Key? key,
    this.itemId,
    this.itemName,
    this.itemDetails,
    this.imageUrl,
    required this.newPrice,
    required this.oldPrice,
    required this.offerType,
  })  : isLoading = false,
        itemMissing = false,
        super(key: key);

  const OfferCard.loading({
    Key? key,
    required this.newPrice,
    required this.oldPrice,
    required this.offerType,
  })  : itemId = null,
        itemName = null,
        itemDetails = null,
        imageUrl = null,
        isLoading = true,
        itemMissing = false,
        super(key: key);

  const OfferCard.missingItem({
    Key? key,
    required String itemId,
    required this.newPrice,
    required this.oldPrice,
    required this.offerType,
  })  : itemId = itemId,
        itemName = 'صنف غير موجود',
        itemDetails = 'لا توجد تفاصيل لهذا الصنف',
        imageUrl = null,
        isLoading = false,
        itemMissing = true,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 90,
                height: 90,
                child: buildImage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? 'جاري التحميل...' : (itemName ?? ''),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLoading ? '' : (itemDetails ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        newPrice.isEmpty ? '-' : newPrice,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        oldPrice.isEmpty ? '' : oldPrice,
                        style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
                      ),
                      const Spacer(),
                      if (offerType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Text(offerType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildImage() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Icon(Icons.image_not_supported, size: 36, color: Colors.grey)),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: const Center(child: Icon(Icons.broken_image, size: 36, color: Colors.grey)),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
