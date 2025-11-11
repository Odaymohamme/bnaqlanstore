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

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['customer_id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profile_image'] ?? '',
      balance: double.tryParse(json['balance'].toString()) ?? 0.0,
    );
  }
}