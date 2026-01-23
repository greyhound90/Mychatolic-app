class Diocese {
  final String id;
  final String name;
  final String countryId;

  Diocese({
    required this.id,
    required this.name,
    required this.countryId,
  });

  factory Diocese.fromJson(Map<String, dynamic> json) {
    return Diocese(
      id: json['id'].toString(),
      name: json['name'] as String,
      countryId: json['country_id'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country_id': countryId,
    };
  }
}
