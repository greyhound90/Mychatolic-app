class MassSchedule {
  final String id;
  final String churchId;
  final String churchName;
  final String? churchParish;
  final String timeStart;
  final String? language;
  final int dayOfWeek;

  MassSchedule({
    required this.id,
    required this.churchId,
    required this.churchName,
    this.churchParish,
    required this.timeStart,
    this.language,
    required this.dayOfWeek,
  });

  factory MassSchedule.fromJson(Map<String, dynamic> json) {
    // 1. Handle Church Info (Joined Data - Optional)
    String cName = 'Gereja';
    String? cInfo;

    if (json['churches'] != null) {
      final cData = json['churches'];
      cName = cData['name'] ?? cName;
      cInfo = cData['parish'] ?? cData['parish_name'] ?? cData['address'];
    }

    // 2. Handle Time (DB: start_time)
    final String time = json['start_time']?.toString() ?? '00:00';

    // 3. Handle Day (DB: day_number)
    int day = 0;
    if (json['day_number'] != null) {
      day = int.tryParse(json['day_number'].toString()) ?? 0;
    }

    return MassSchedule(
      id: json['id']?.toString() ?? '',
      churchId: json['church_id']?.toString() ?? '',
      churchName: cName,
      churchParish: cInfo,
      timeStart: time,
      language: json['language'],
      dayOfWeek: day,
    );
  }
}
