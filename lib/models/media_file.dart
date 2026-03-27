/// Status of a media file in the processing pipeline.
enum MediaFileStatus { pending, processing, done, error }

/// Represents a media file added by the user for conversion or merging.
class MediaFile {
  final String path;
  final String name;
  final bool isRemote;
  MediaFileStatus status;
  double progress;
  String? errorMessage;
  String? eta;
  String? outputPath;

  MediaFile({
    required this.path,
    required this.name,
    this.isRemote = false,
    this.status = MediaFileStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.eta,
    this.outputPath,
  });

  MediaFile copyWith({
    String? path,
    String? name,
    bool? isRemote,
    MediaFileStatus? status,
    double? progress,
    String? errorMessage,
    String? eta,
    String? outputPath,
  }) {
    return MediaFile(
      path: path ?? this.path,
      name: name ?? this.name,
      isRemote: isRemote ?? this.isRemote,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      eta: eta ?? this.eta,
      outputPath: outputPath ?? this.outputPath,
    );
  }
}
