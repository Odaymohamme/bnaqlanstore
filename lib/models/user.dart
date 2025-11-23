class User {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String profileImage;
  final double balance;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.profileImage,
    required this.balance,
  });

  /// محاولات للحصول على قيمة id من أماكن مختلفة داخل الـ JSON
  static int _extractId(Map<String, dynamic> json) {
    // حالات شائعة: 'customer_id', 'id', 'user_id'
    final possible = <String>['customer_id', 'id', 'user_id', 'userId'];

    for (final key in possible) {
      if (json.containsKey(key)) {
        final v = json[key];
        if (v is int) return v;
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
    }

    // لو كان الكائن داخل 'data' أو 'customer'
    if (json['data'] is Map) {
      final nested = Map<String, dynamic>.from(json['data']);
      final r = _extractId(nested);
      if (r > 0) return r;
    }
    if (json['customer'] is Map) {
      final nested = Map<String, dynamic>.from(json['customer']);
      final r = _extractId(nested);
      if (r > 0) return r;
    }

    return 0;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final id = _extractId(json);
    // إذا الاستجابة كاملة ضمن مفتاح 'data' أو 'customer'، استخدم تلك الخريطة إذا متاحة
    Map<String, dynamic> source = json;
    if (json['data'] is Map) {
      source = Map<String, dynamic>.from(json['data']);
    } else if (json['customer'] is Map) {
      source = Map<String, dynamic>.from(json['customer']);
    }

    return User(
      id: id,
      name: source['name']?.toString() ?? '',
      phone: source['phone']?.toString() ?? '',
      email: source['email']?.toString() ?? '',
      profileImage: source['profile_image']?.toString() ?? '',
      balance: double.tryParse(source['balance']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'profile_image': profileImage,
      'balance': balance,
    };
  }
}
