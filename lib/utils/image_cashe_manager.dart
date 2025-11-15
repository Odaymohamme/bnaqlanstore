// lib/utils/image_cache_manager.dart

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// مدير كاش مركزي للصور + دالة لمعادلة/إصلاح روابط صور المنتجات.
class MyImageCacheManager {
  MyImageCacheManager._(); // منع الإنشاء (فئة util ثابتة)

  static const String key = 'aqlanStoreImageCache';

  /// CacheManager واحد يتم إعادة استخدامه طوال التطبيق.
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// يحول اسم الملف الخام أو الحقل من Firestore إلى رابط صالح للعرض.
  /// يدعم:
  ///  - قيم null أو فارغة -> يعيد سلسلة فارغة.
  ///  - روابط كاملة (تبدأ بـ http أو تحتوي /storage/v1/object) -> يعيدها كما هي.
  ///  - أسماء ملفات -> يبني رابط Supabase الافتراضي لمجلد products.
  static String resolveProductImageUrl(String? raw) {
    if (raw == null) return "";
    final s = raw.toString().trim();
    if (s.isEmpty) return "";

    // إذا هو رابط كامل أو يحتوي على مسار supabase بالفعل، أعده كما هو
    if (s.startsWith('http') || s.contains('/storage/v1/object')) {
      return s;
    }

    // إن لم يكن رابط كامل، افترض أنه اسم ملف داخل bucket "products"
    return 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public/products/$s';
  }
}
