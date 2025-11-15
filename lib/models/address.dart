class Address {
  final String id;
  final String label;
  final String address;
  final String mapLink;

  Address({
    required this.id,
    required this.label,
    required this.address,
    required this.mapLink,
  });

  factory Address.fromFirestore(Map<String, dynamic> data, String docId) {
    return Address(
        id: docId,
        label: data["label"]?.toString() ?? "",
        address: data["address"]?.toString() ?? "",
        mapLink: data["map_link"]?.toString() ?? "",
        );
    }
}