class Country {
  final String id;
  final String name;
  final String? flagEmoji;

  Country({
    required this.id,
    required this.name,
    this.flagEmoji,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'].toString(),
      name: json['name'] as String,
      flagEmoji: json['flag_emoji'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'flag_emoji': flagEmoji,
    };
  }
}
