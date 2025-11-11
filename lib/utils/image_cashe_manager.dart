// lib/utils/image_cache_manager.dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MyImageCacheManager {
  static const key = 'aqlanStoreImageCache';

  static CacheManager instance = CacheManager(
      Config(
          key,
          stalePeriod: const Duration(days: 365), // مدة بقاء الصورة في الكاش
          maxNrOfCacheObjects: 1000, // عدد الملفات المخزنة حد أقصى
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(), // الافتراضي
          ),
      );
}