class Church {
  final String id; // UUID usually strings in Dart
  final String name;
  final String? dioceseId;
  final String? imageUrl;
  final String? address;

  Church({
    required this.id,
    required this.name,
    this.dioceseId,
    this.imageUrl,
    this.address,
  });

  factory Church.fromJson(Map<String, dynamic> json) {
    return Church(
      id: json['id'].toString(), // Handle if it's int or uuid string
      name: json['name'] as String,
      dioceseId: json['diocese_id']?.toString(), // Handle int or uuid string
      imageUrl: json['image_url'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'diocese_id': dioceseId,
      'image_url': imageUrl,
      'address': address,
    };
  }
}
