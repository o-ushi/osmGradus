import 'dart:collection';

import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  LogEntry(this.timestamp, this.level, this.message);
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  @override
  String toString() {
    final tag = switch (level) {
      LogLevel.info => 'INFO',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERROR',
    };
    return '${timestamp.toIso8601String()} [$tag] $message';
  }
}

/// osmPodの `DebugLogExporter`（OSLogStoreから直近ログを抜き出して共有）に相当。
/// FlutterにOSLogStore相当のAPIはないため、アプリ内リングバッファに要点のみ
/// 記録し、開発者モード時に共有できるようにする。
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const _developerModeKey = 'dev.developerModeEnabled';
  static const _maxEntries = 300;

  final Queue<LogEntry> _entries = Queue<LogEntry>();
  bool developerModeEnabled = false;

  Future<void> loadDeveloperMode() async {
    final prefs = await SharedPreferences.getInstance();
    developerModeEnabled = prefs.getBool(_developerModeKey) ?? false;
  }

  Future<void> setDeveloperModeEnabled(bool value) async {
    developerModeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_developerModeKey, value);
  }

  void log(String message, {LogLevel level = LogLevel.info}) {
    _entries.addLast(LogEntry(DateTime.now(), level, message));
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
  }

  List<LogEntry> get entries => List.unmodifiable(_entries);

  String exportAsText() {
    if (_entries.isEmpty) return 'ログはまだありません。';
    return _entries.map((e) => e.toString()).join('\n');
  }
}
