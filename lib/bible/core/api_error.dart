class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiErrorMapper {
  static String toUserMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('timeout')) {
      return 'Koneksi timeout. Coba lagi.';
    }
    if (raw.contains('socket') || raw.contains('network')) {
      return 'Tidak ada koneksi internet.';
    }
    if (raw.contains('401') || raw.contains('unauthorized')) {
      return 'Sesi berakhir. Silakan login ulang.';
    }
    if (raw.contains('403')) {
      return 'Anda tidak memiliki akses.';
    }
    if (raw.contains('404')) {
      return 'Data tidak ditemukan.';
    }
    if (raw.contains('500')) {
      return 'Server sedang bermasalah. Coba lagi nanti.';
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
