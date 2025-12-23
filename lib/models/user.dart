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

  /// استخراج ID بشكل آمن من أي مصدر
  static int _extractId(Map<String, dynamic> json) {
    final possibleKeys = ['customer_id', 'id', 'user_id', 'userId'];

    for (final key in possibleKeys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }

    if (json['data'] is Map) {
      return _extractId(Map<String, dynamic>.from(json['data']));
    }

    if (json['customer'] is Map) {
      return _extractId(Map<String, dynamic>.from(json['customer']));
    }

    return 0;
  }

  /// استخدام عام (API / Session / أي مصدر)
  factory User.fromJson(Map<String, dynamic> json) {
    final source = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'])
        : (json['customer'] is Map)
        ? Map<String, dynamic>.from(json['customer'])
        : json;

    return User(
      id: _extractId(json),
      name: source['name']?.toString() ?? '',
      phone: source['phone']?.toString() ?? '',
      email: source['email']?.toString() ?? '',
      profileImage: source['profile_image']?.toString() ?? '',
      balance: (source['balance'] is num)
          ? (source['balance'] as num).toDouble()
          : double.tryParse(source['balance']?.toString() ?? '0') ?? 0.0,
    );
  }

  /// 🔥 خاص بـ Firestore (مهم جدًا للويب و iOS)
  factory User.fromFirestore(Map<String, dynamic> data) {
    return User(
      id: (data['customer_id'] is num)
          ? (data['customer_id'] as num).toInt()
          : int.tryParse(data['customer_id']?.toString() ?? '0') ?? 0,
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      profileImage: data['profile_image']?.toString() ?? '',
      balance: (data['balance'] is num)
          ? (data['balance'] as num).toDouble()
          : double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'profile_image': profileImage,
      'balance': balance,
    };
  }
}
