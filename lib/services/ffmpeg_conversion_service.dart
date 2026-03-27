import 'dart:convert';
import 'dart:io';

import '../models/audio_format.dart';
import 'log_service.dart';

/// Service for converting video files to audio using ffmpeg.
class FfmpegConversionService {
  /// Converts a video file at [inputPath] to audio, writing to [outputPath].
  ///
  /// The [onProcessStarted] callback provides the underlying `Process` so it can be killed.
  /// The [onProgress] callback provides real-time progress between 0.0 and 1.0.
  /// Returns the [ProcessResult] from ffmpeg.
  static Future<ProcessResult> convertVideoToAudio({
    required String inputPath,
    required String outputPath,
    required AudioFormat format,
    required String bitrate,
    void Function(Process)? onProcessStarted,
    void Function(double, String)? onProgress,
  }) async {
    final args = [
      '-y', // overwrite
      '-nostdin', // prevent FFMPEG from waiting for interactive input
      '-progress', 'pipe:1', // write machine-readable progress to stdout
      '-i', inputPath,
      '-vn', // strip video
      ...codecArgsForFormat(format, bitrate: bitrate),
      outputPath,
    ];

    final logService = LogService();
    logService.clear();
    logService.addLog('Running: ffmpeg ${args.join(' ')}');

    final process = await Process.start('ffmpeg', args);
    if (onProcessStarted != null) onProcessStarted(process);

    final stderrBuffer = StringBuffer();
    Duration? totalDuration;

    // Use a raw string buffer to handle \r-delimited FFmpeg output.
    String stderrPartial = '';
    process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
      logService.addLog(data);

      // Split on both \r and \n to handle FFmpeg's progress output.
      stderrPartial += data;
      final lines = stderrPartial.split(RegExp(r'[\r\n]+'));
      // Keep the last element as partial (may be incomplete).
      stderrPartial = lines.removeLast();

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        // Parse Duration: 00:00:00.00
        if (totalDuration == null && line.contains('Duration:')) {
          final match = RegExp(
            r'Duration:\s+(\d+):(\d+):(\d+\.\d+)',
          ).firstMatch(line);
          if (match != null) {
            final hours = int.parse(match.group(1)!);
            final mins = int.parse(match.group(2)!);
            final secs = double.parse(match.group(3)!);
            totalDuration = Duration(
              milliseconds:
                  (hours * 3600000 + mins * 60000 + secs * 1000).toInt(),
            );
          }
        }

        // Parse time=00:00:00.00 and speed=1.5x
        if (totalDuration != null &&
            totalDuration!.inMilliseconds > 0 &&
            onProgress != null) {
          final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
          if (match != null) {
            final hours = int.parse(match.group(1)!);
            final mins = int.parse(match.group(2)!);
            final secs = double.parse(match.group(3)!);
            final currentMs =
                (hours * 3600000 + mins * 60000 + secs * 1000).toInt();

            double progress = currentMs / totalDuration!.inMilliseconds;
            if (progress > 1.0) progress = 1.0;
            if (progress < 0.0) progress = 0.0;

            String eta = '';
            final speedMatch = RegExp(r'speed=\s*([\d\.]+)x').firstMatch(line);
            if (speedMatch != null && progress > 0.0 && progress < 1.0) {
              final speed = double.tryParse(speedMatch.group(1)!) ?? 0.0;
              if (speed > 0) {
                final remainingRealMs =
                    (totalDuration!.inMilliseconds - currentMs) / speed;
                final remainingSecs = (remainingRealMs / 1000).round();
                if (remainingSecs < 60) {
                  eta = '${remainingSecs}s';
                } else {
                  final m = remainingSecs ~/ 60;
                  final s = remainingSecs % 60;
                  eta = '${m}m ${s}s';
                }
              }
            }
            onProgress(progress, eta);
          }
        }
      }
    });

    final exitCode = await process.exitCode;

    if (onProgress != null && exitCode == 0) {
      onProgress(1.0, '');
    }

    return ProcessResult(process.pid, exitCode, '', stderrBuffer.toString());
  }
}
