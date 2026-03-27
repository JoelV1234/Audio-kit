/// Supported output audio formats.
enum AudioFormat { opus, mp3, heAac }

/// Returns the file extension for the given [format].
String extensionForFormat(AudioFormat format) {
  switch (format) {
    case AudioFormat.opus:
      return '.opus';
    case AudioFormat.mp3:
      return '.mp3';
    case AudioFormat.heAac:
      return '.m4a';
  }
}

/// Returns a human-readable label for the given [format].
String labelForFormat(AudioFormat format) {
  switch (format) {
    case AudioFormat.opus:
      return 'Opus';
    case AudioFormat.mp3:
      return 'MP3';
    case AudioFormat.heAac:
      return 'HE-AAC';
  }
}

/// Returns the ffmpeg muxer format name for the given [format].
String ffmpegFormatName(AudioFormat format) {
  switch (format) {
    case AudioFormat.opus:
      return 'opus';
    case AudioFormat.mp3:
      return 'mp3';
    case AudioFormat.heAac:
      return 'ipod'; // MP4/M4A container
  }
}

/// Returns the ffmpeg codec arguments for the given [format].
/// If [bitrate] is provided (e.g. '192k') it is used as a CBR target;
/// otherwise sensible defaults are applied.
List<String> codecArgsForFormat(AudioFormat format, {String? bitrate}) {
  switch (format) {
    case AudioFormat.opus:
      return ['-c:a', 'libopus', '-b:a', bitrate ?? '128k'];
    case AudioFormat.mp3:
      if (bitrate != null) {
        return ['-c:a', 'libmp3lame', '-b:a', bitrate];
      }
      return ['-c:a', 'libmp3lame', '-q:a', '2'];
    case AudioFormat.heAac:
      return ['-c:a', 'aac', '-profile:a', 'aac_he', '-b:a', bitrate ?? '64k'];
  }
}
