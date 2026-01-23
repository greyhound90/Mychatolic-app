class Schedule {
  final String id; // UUID
  final String churchId;
  final int dayOfWeek; // 0=Minggu, 1=Senin...
  final String timeStart; // "HH:MM:SS"
  final String? language;
  final String? label; 

  Schedule({
    required this.id,
    required this.churchId,
    required this.dayOfWeek,
    required this.timeStart,
    this.language,
    this.label,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // 1. Mandatory Fields: id & church_id
    // This will throw a generic error (TypeError/CastError) if null or not a String
    final String id = json['id'] as String;
    final String churchId = json['church_id'] as String;

    // 2. Mandatory Field: day_of_week
    // Ensure it's parsed correctly as int, or throw an error
    final dynamic rawDay = json['day_of_week'];
    if (rawDay == null) {
      throw FormatException('Missing required field: day_of_week');
    }
    
    int dayOfWeek;
    if (rawDay is int) {
      dayOfWeek = rawDay;
    } else if (rawDay is String) {
      dayOfWeek = int.parse(rawDay); // Throws FormatException if invalid
    } else {
      throw FormatException('Invalid day_of_week format: ${rawDay.runtimeType}');
    }

    // 3. Mandatory Field: time_start
    final String timeStart = json['time_start'] as String;

    // 4. Optional Fields: language & label (Safe Parsing)
    // We allow nulls here, but ensure if data exists it is converted to String
    final String? language = json['language']?.toString();
    final String? label = json['label']?.toString();

    return Schedule(
      id: id,
      churchId: churchId,
      dayOfWeek: dayOfWeek,
      timeStart: timeStart,
      language: language,
      label: label,
    );
  }

  // Getter for Display
  String get dayName {
     const days = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
     if (dayOfWeek >= 0 && dayOfWeek < days.length) return days[dayOfWeek];
     return "Minggu";
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'church_id': churchId,
      'day_of_week': dayOfWeek,
      'time_start': timeStart,
      'language': language,
      'label': label,
    };
  }
}
