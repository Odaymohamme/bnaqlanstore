// lib/widgets/app_image.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cashe_manager.dart';

/// ويدجت مركزي لعرض الصور (شبكة أو محلية أو اسم ملف)
class AppImage extends StatelessWidget {
  final String? src; // رابط، اسم ملف، أو مسار محلي
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isCircular;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImage({
    Key? key,
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isCircular = false,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.contains('/object/sign/')) {
      final match = RegExp(r'(/products/[^?\s/]+\.(?:jpg|jpeg|png|webp))').firstMatch(url);
      if (match != null) {
        final path = match.group(1)!;
        return 'https://nrjwzdkhwcqokwlmkzem.supabase.co/storage/v1/object/public$path';
      }
    }
    if (url.startsWith('http')) return url;
    return url;
  }

  // placeholder ثابت بحجم محدد لمنع تغيّر الـ layout أثناء التحميل
  Widget _defaultPlaceholder(double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  // خطأ → صورة احتياطية محلية (مع استبعادها من semantics)
  Widget _defaultError(double w, double h, BoxFit fit) {
    return SizedBox(
      width: w,
      height: h,
      child: Image.asset(
        'assets/aqlanassets.jpg',
        width: w,
        height: h,
        fit: fit,
        excludeFromSemantics: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double w = width ?? 50.0;
    final double h = height ?? 50.0;
    final br = borderRadius ?? (isCircular ? BorderRadius.circular(9999) : null);

    // رابط فارغ → عرض الخطأ الافتراضي داخل SizedBox (ثابت القياس)
    if (src == null || src!.trim().isEmpty) {
      final widgetToShow = errorWidget ?? _defaultError(w, h, fit);
      final sized = SizedBox(width: w, height: h, child: widgetToShow);
      final out = br != null ? ClipRRect(borderRadius: br, child: ExcludeSemantics(child: sized)) : ExcludeSemantics(child: sized);
      return out;
    }

    final s = src!.trim();

    // local file path
    if (s.startsWith('file://') || s.startsWith('/') || s.startsWith('C:') || s.startsWith(r'\\')) {
      final path = s.startsWith('file://') ? s.replaceFirst('file://', '') : s;
      final file = File(path);
      final widgetToShow = (file.existsSync())
          ? SizedBox(
        width: w,
        height: h,
        child: Image.file(file, width: w, height: h, fit: fit, excludeFromSemantics: true),
      )
          : (errorWidget ?? _defaultError(w, h, fit));
      final out = br != null ? ClipRRect(borderRadius: br, child: ExcludeSemantics(child: widgetToShow)) : ExcludeSemantics(child: widgetToShow);
      return out;
    }

    // network
    final resolved = MyImageCacheManager.resolveProductImageUrl(s);
    final finalUrl = _fixUrl(resolved);

    // نستخدم KeyedSubtree فقط عندما لدينا finalUrl ثابت لتثبيت هوية الودجت
    final Key? subtreeKey = finalUrl.isNotEmpty ? ValueKey(finalUrl) : null;

    final networkWidget = SizedBox(
      width: w,
      height: h,
      child: CachedNetworkImage(
        key: ValueKey(finalUrl),
        cacheManager: MyImageCacheManager.instance,
        imageUrl: finalUrl,
        width: w,
        height: h,
        fit: fit,
        // لإيقاف انتقالات التأثيرات التي قد تغيّر الـ semantics tree
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        // حافظ على الصورة القديمة إذا تغيّر URL مؤقتًا لتقليل إعادة بناء الـ renderobject
        useOldImageOnUrlChange: true,
        // نصنع الصورة النهائية باستخدام imageBuilder ونستبعدها من semantics
        imageBuilder: (context, imageProvider) {
          return Image(
            image: imageProvider,
            width: w,
            height: h,
            fit: fit,
            excludeFromSemantics: true,
          );
        },
        placeholder: (ctx, url) => placeholder ?? _defaultPlaceholder(w, h),
        errorWidget: (ctx, url, err) => errorWidget ?? _defaultError(w, h, fit),
      ),
    );

    final wrapped = subtreeKey != null ? KeyedSubtree(key: subtreeKey, child: ExcludeSemantics(child: networkWidget)) : ExcludeSemantics(child: networkWidget);

    // ClipRRect إن كان مطلوبًا للحواف
    return br != null ? ClipRRect(borderRadius: br, child: wrapped) : wrapped;
  }
}
