import 'package:flutter/material.dart';

/// Shows a dialog with ffmpeg error output.
///
/// Used by both the Video to Audio and Audio Merger features when an
/// ffmpeg process exits with a non-zero exit code.
void showFfmpegErrorDialog(
  BuildContext context, {
  required String title,
  String? fileName,
  required String stderr,
}) {
  showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 36),
          title: Text(title),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fileName != null) ...[
                  Text(
                    'File: $fileName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      stderr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
  );
}
