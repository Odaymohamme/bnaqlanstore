import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
/////////////تم الايقاف مؤقتا

class StoreContactScreen extends StatefulWidget {
  const StoreContactScreen({Key? key}) : super(key: key);

  @override
  State<StoreContactScreen> createState() => _StoreContactScreenState();
}

class _StoreContactScreenState extends State<StoreContactScreen> {
  Map<String, dynamic>? storeData;
  bool _loading = true;

  get store => 773995334;

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    try {
      final data = await ApiService.fetchStoreInfo(); // جلب بيانات المتجر
      setState(() {
        storeData = data;
      });
    } catch (e) {
      debugPrint("❌ خطأ جلب بيانات المتجر: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("لا يمكن فتح الرابط: $url")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("من نحن"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : storeData == null
            ? const Center(child: Text("⚠ لا توجد بيانات"))
            : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // صورة المتجر (دائرية مع زووم)
                if (storeData!['image'] != null &&
                    storeData!['image'].toString().isNotEmpty)
                  CircleAvatar(
                    radius: 80,
                    backgroundImage: NetworkImage(
                      "${Constants.baseUrl}/uploads/${storeData!['image']}",
                    ),
                  ),

                const SizedBox(height: 20),

                // اسم المتجر
                Text(
                  storeData!['name'] ?? "متجرنا",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                // الوصف
                Text(
                  storeData!['description'] ?? "",
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                // ✅ أيقونات التواصل (واتساب + فيسبوك + إنستغرام)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // واتساب
                    IconButton(
                      icon: Image.asset(
                        "assets/images/whatsapp.png",
                        width: 28,
                        height: 28,
                      ),
                      onPressed: () {
                        final phone = store['phone']; // رقم المتجر
                        final url = "https://wa.me/$phone";
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        },
                    ),
                    const SizedBox(width: 20),

                    // فيسبوك
                    IconButton(
                      icon: const Icon(Icons.facebook,
                          color: Colors.blue, size: 40),
                      onPressed: () {
                        final fb = storeData!['facebook'] ?? "";
                        if (fb.isNotEmpty) {
                          _launchUrl(fb);
                        }
                      },
                    ),
                    const SizedBox(width: 20),

                    // إنستغرام
                    IconButton(
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.purple, size: 40),
                      onPressed: () {
                        final insta = storeData!['instagram'] ?? "";
                        if (insta.isNotEmpty) {
                          _launchUrl(insta);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ✅ عرض رقم الهاتف كـ Contact فقط إذا تحب يظهر (اختياري)
                if (storeData!['mobile'] != null &&
                    storeData!['mobile'].toString().isNotEmpty)
                  Text(
                    "📞 للتواصل: ${storeData!['mobile']}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            ),
        );
    }
}