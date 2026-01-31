import 'package:flutter/foundation.dart';

class AppLogger {
  static void logInfo(String message) {
    if (kDebugMode) {
      debugPrint("[INFO] $message");
    }
  }

  static void logWarn(String message) {
    if (kDebugMode) {
      debugPrint("[WARN] $message");
    }
  }

  static void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint("[ERROR] $message");
      if (error != null) debugPrint("  error: $error");
      if (stackTrace != null) debugPrint("  stack: $stackTrace");
    }
  }
}
