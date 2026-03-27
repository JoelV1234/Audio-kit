import 'dart:convert';
import 'dart:io';

import '../models/audio_format.dart';
import 'log_service.dart';

/// Service for merging audio files using ffmpeg.
class FfmpegMergeService {
  /// Merges multiple audio files into one output file.
  ///
  /// Creates a temporary concat file, runs ffmpeg concat demuxer, then cleans up.
  static Future<ProcessResult> mergeAudioFiles({
    required List<String> inputPaths,
    required String outputPath,
    required AudioFormat format,
    void Function(Process)? onProcessStarted,
    void Function(double, String)? onProgress,
  }) async {
    final logService = LogService();
    logService.clear();

    // Create a temporary concat list file.
    final tempDir = await Directory.systemTemp.createTemp('audiokit_');
    final concatFile = File('${tempDir.path}/concat.txt');

    // We first convert each input to a common PCM WAV so concat works across
    // different source formats, then concat the wav files, then encode to the
    // target format.
    final wavFiles = <String>[];
    double totalSourceDurationMs = 0;

    for (var i = 0; i < inputPaths.length; i++) {
      final wavPath = '${tempDir.path}/part_$i.wav';
      logService.addLog('Converting part $i (${inputPaths[i]}) to WAV...');
      final process = await Process.start('ffmpeg', [
        '-y',
        '-nostdin',
        '-i',
        inputPaths[i],
        '-ar',
        '44100',
        '-ac',
        '2',
        '-f',
        'wav',
        wavPath,
      ]);

      if (onProcessStarted != null) onProcessStarted(process);

      process.stdout.transform(utf8.decoder).listen((data) {
        logService.addLog(data);
      });

      String wavStderrPartial = '';
      process.stderr.transform(utf8.decoder).listen((data) {
        logService.addLog(data);
        // Split on both \r and \n to handle FFmpeg's output.
        wavStderrPartial += data;
        final lines = wavStderrPartial.split(RegExp(r'[\r\n]+'));
        wavStderrPartial = lines.removeLast();
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          // Parse Duration: 00:00:00.00 to sum it up.
          if (line.contains('Duration:')) {
            final match = RegExp(
              r'Duration:\s+(\d+):(\d+):(\d+\.\d+)',
            ).firstMatch(line);
            if (match != null) {
              final hours = int.parse(match.group(1)!);
              final mins = int.parse(match.group(2)!);
              final secs = double.parse(match.group(3)!);
              final ms = (hours * 3600000 + mins * 60000 + secs * 1000).toInt();
              totalSourceDurationMs += ms;
            }
          }
        }
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        // Clean up temp dir
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
        return ProcessResult(
          process.pid,
          exitCode,
          '',
          'WAV conversion failed or cancelled',
        );
      }
      wavFiles.add(wavPath);
      if (onProgress != null) {
        onProgress(((i + 1) / inputPaths.length) * 0.4, 'Analyzing...');
      }
    }

    // Write the concat list.
    final concatContent = wavFiles
        .map((p) => "file '${p.replaceAll("'", "'\\''")}'")
        .join('\n');
    await concatFile.writeAsString(concatContent);

    // Run ffmpeg concat.
    final args = [
      '-y',
      '-nostdin',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      concatFile.path,
      ...codecArgsForFormat(format),
      '-f', ffmpegFormatName(format),
      outputPath,
    ];

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
      stderrPartial = lines.removeLast();

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        // Parse duration
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

        // Parse time and speed
        if ((totalDuration != null || totalSourceDurationMs > 0) &&
            onProgress != null) {
          final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
          if (match != null) {
            final hours = int.parse(match.group(1)!);
            final mins = int.parse(match.group(2)!);
            final secs = double.parse(match.group(3)!);
            final currentMs =
                (hours * 3600000 + mins * 60000 + secs * 1000).toInt();

            // Use calculated total if FFmpeg didn't provide one for concat.
            final targetDuration =
                totalDuration?.inMilliseconds ??
                (totalSourceDurationMs > 0 ? totalSourceDurationMs : 0);

            double progress = 0.4;
            if (targetDuration > 0) {
              progress = 0.4 + (currentMs / targetDuration) * 0.6;
            }
            if (progress > 1.0) progress = 1.0;
            if (progress < 0.4) progress = 0.4;

            String eta = '';
            final speedMatch = RegExp(r'speed=\s*([\d\.]+)x').firstMatch(line);
            if (speedMatch != null && progress > 0.4 && progress < 1.0) {
              final speed = double.tryParse(speedMatch.group(1)!) ?? 0.0;
              if (speed > 0) {
                final remainingRealMs = (targetDuration - currentMs) / speed;
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
    // Clean up.
    await tempDir.delete(recursive: true);

    if (onProgress != null && exitCode == 0) {
      onProgress(1.0, '');
    }
    return ProcessResult(process.pid, exitCode, '', stderrBuffer.toString());
  }
}
