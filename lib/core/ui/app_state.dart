import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AppViewState { loading, error, empty, ready }

class AppError {
  final String title;
  final String message;
  final Object? raw;
  final StackTrace? st;

  const AppError({
    required this.title,
    required this.message,
    this.raw,
    this.st,
  });
}

String mapErrorMessage(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception') || msg.contains('network')) {
    return "Koneksi bermasalah. Coba lagi.";
  }
  if (msg.contains('jwt') || msg.contains('session') || msg.contains('auth')) {
    return "Sesi berakhir. Silakan login ulang.";
  }
  if (msg.contains('not found') || msg.contains('404')) {
    return "Data belum tersedia.";
  }
  return "Terjadi kesalahan. Coba lagi.";
}

extension StateX<T extends StatefulWidget> on State<T> {
  bool get mountedSafe => mounted;

  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }
}
