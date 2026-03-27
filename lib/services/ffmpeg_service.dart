import 'dart:io';

/// Service for checking ffmpeg availability.
class FfmpegService {
  /// Checks that ffmpeg is available on the system.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
