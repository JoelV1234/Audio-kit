import 'dart:async';

/// A service to collect and broadcast logs from the terminal (FFmpeg processes).
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<String> _logs = [];
  final _controller = StreamController<List<String>>.broadcast();

  /// Stream of the full list of logs.
  Stream<List<String>> get logStream => _controller.stream;

  /// Current list of logs.
  List<String> get logs => List.unmodifiable(_logs);

  /// Adds a log line and broadcasts.
  void addLog(String line) {
    if (line.trim().isEmpty) return;
    _logs.add(line);
    // Keep a reasonable limit (e.g., 5000 lines) to prevent memory issues.
    if (_logs.length > 5000) {
      _logs.removeAt(0);
    }
    _controller.add(_logs);
  }

  /// Clears the logs.
  void clear() {
    _logs.clear();
    _controller.add(_logs);
  }
}
