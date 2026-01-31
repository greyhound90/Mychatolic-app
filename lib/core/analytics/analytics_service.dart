import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mychatolic_app/core/log/app_logger.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  static const String _prefsDeviceId = 'analytics_device_id';
  static const String _prefsSessionId = 'analytics_session_id';
  static const String _prefsSessionStart = 'analytics_session_start';
  static const String _prefsEnabled = 'analytics_enabled';

  static const Duration _sessionTimeout = Duration(hours: 6);
  static const int _maxBatchSize = 20;
  static const int _maxProps = 20;
  static const int _maxStringLength = 80;

  final SupabaseClient _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _queue = [];

  SharedPreferences? _prefs;
  Timer? _flushDebounce;
  bool _enabled = true;
  bool _initialized = false;
  bool _flushing = false;

  String? _deviceId;
  String? _sessionId;
  DateTime? _lastSessionStart;

  bool get isEnabled => _enabled;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_prefsEnabled) ?? true;
    _deviceId = _prefs?.getString(_prefsDeviceId);
    _sessionId = _prefs?.getString(_prefsSessionId);
    final storedStart = _prefs?.getString(_prefsSessionStart);
    if (storedStart != null) {
      _lastSessionStart = DateTime.tryParse(storedStart);
    }
    _deviceId ??= _generateId();
    await _prefs?.setString(_prefsDeviceId, _deviceId!);
    _initialized = true;
    if (_enabled) {
      await startSessionIfNeeded(force: true);
    }
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    _prefs?.setBool(_prefsEnabled, enabled);
    if (!enabled) {
      _queue.clear();
      _flushDebounce?.cancel();
    }
  }

  Future<void> startSessionIfNeeded({bool force = false}) async {
    if (!_enabled) return;
    if (!_initialized) return;
    final now = DateTime.now();
    final expired = _lastSessionStart == null ||
        now.difference(_lastSessionStart!) > _sessionTimeout;
    if (force || _sessionId == null || expired) {
      _sessionId = _generateId();
      _lastSessionStart = now;
      await _prefs?.setString(_prefsSessionId, _sessionId!);
      await _prefs?.setString(_prefsSessionStart, now.toIso8601String());
    }
  }

  void track(
    String eventName, {
    String? screenName,
    Map<String, dynamic> props = const {},
  }) {
    if (!_enabled || !_initialized) return;
    if (_deviceId == null) return;

    if (_sessionId == null || _lastSessionStart == null) {
      _sessionId = _generateId();
      _lastSessionStart = DateTime.now();
      unawaited(_prefs?.setString(_prefsSessionId, _sessionId!));
      unawaited(
          _prefs?.setString(_prefsSessionStart, _lastSessionStart!.toIso8601String()));
    } else {
      final expired =
          DateTime.now().difference(_lastSessionStart!) > _sessionTimeout;
      if (expired) {
        _sessionId = _generateId();
        _lastSessionStart = DateTime.now();
        unawaited(_prefs?.setString(_prefsSessionId, _sessionId!));
        unawaited(
            _prefs?.setString(_prefsSessionStart, _lastSessionStart!.toIso8601String()));
      }
    }

    final sanitizedScreen = _sanitizeString(screenName);
    final event = <String, dynamic>{
      'user_id': _supabase.auth.currentUser?.id,
      'device_id': _deviceId,
      'session_id': _sessionId,
      'event_name': eventName,
      'screen_name': sanitizedScreen.isEmpty ? null : sanitizedScreen,
      'properties': _sanitizeProps(props),
      'app_version': _appVersion,
      'platform': Platform.operatingSystem,
    };

    _queue.add(event);
    if (_queue.length >= _maxBatchSize) {
      unawaited(flush());
    } else {
      _scheduleFlush();
    }
  }

  void trackScreen(String screenName, {Map<String, dynamic> props = const {}}) {
    track(AnalyticsEvents.screenView, screenName: screenName, props: props);
  }

  Future<void> flush() async {
    if (!_enabled || !_initialized) return;
    if (_queue.isEmpty || _flushing) return;
    if (_supabase.auth.currentSession == null) return;

    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final batchSize = _queue.length >= _maxBatchSize
            ? _maxBatchSize
            : _queue.length;
        final batch = _queue.sublist(0, batchSize);
        await _supabase.from('analytics_events').insert(batch);
        _queue.removeRange(0, batchSize);
      }
    } catch (e) {
      AppLogger.logWarn("Analytics flush failed: ${_shortError(e)}");
    } finally {
      _flushing = false;
    }
  }

  void _scheduleFlush() {
    _flushDebounce?.cancel();
    _flushDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(flush());
    });
  }

  Map<String, dynamic> _sanitizeProps(Map<String, dynamic> props) {
    final cleaned = <String, dynamic>{};
    var count = 0;
    props.forEach((key, value) {
      if (count >= _maxProps) return;
      final k = key.toString();
      final kLower = k.toLowerCase();
      if (_isSensitiveKey(kLower)) return;

      if (value is bool || value is num) {
        cleaned[k] = value;
        count++;
        return;
      }
      if (value is String) {
        cleaned[k] = _sanitizeString(value);
        count++;
        return;
      }
    });
    return cleaned;
  }

  String _sanitizeString(String? value) {
    if (value == null) return '';
    if (value.length <= _maxStringLength) return value;
    return value.substring(0, _maxStringLength);
  }

  bool _isSensitiveKey(String key) {
    const blocked = [
      'email',
      'phone',
      'name',
      'message',
      'content',
      'text',
      'address',
    ];
    for (final b in blocked) {
      if (key.contains(b)) return true;
    }
    return false;
  }

  String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String _shortError(Object? error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('socket')) return 'network';
    if (msg.contains('timeout')) return 'timeout';
    if (msg.contains('auth') || msg.contains('jwt')) return 'auth';
    if (msg.contains('permission')) return 'permission';
    if (msg.contains('invalid')) return 'invalid';
    return 'unknown';
  }

  String get _appVersion {
    const name = String.fromEnvironment('FLUTTER_BUILD_NAME');
    return name.isNotEmpty ? name : 'unknown';
  }

  static String errorCode(Object? error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('socket')) return 'network';
    if (msg.contains('timeout')) return 'timeout';
    if (msg.contains('auth') || msg.contains('jwt')) return 'auth';
    if (msg.contains('permission')) return 'permission';
    if (msg.contains('invalid')) return 'invalid';
    return 'unknown';
  }
}
