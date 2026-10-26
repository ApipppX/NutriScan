import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Thin logging facade. Swap the implementation for Crashlytics/Sentry in
/// production without touching feature code.
abstract final class AppLogger {
  static const String _name = 'NutriScan';

  static void debug(String message) {
    if (kDebugMode) {
      developer.log(message, name: _name);
    }
  }

  static void info(String message) {
    developer.log(message, name: _name);
  }

  static void error(String message, Object error, [StackTrace? stackTrace]) {
    developer.log(
      message,
      name: _name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
