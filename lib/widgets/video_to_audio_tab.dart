import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/media_file.dart';
import '../services/ffmpeg_service.dart';
import '../services/notification_service.dart';

/// Tab for converting video files (mp4) to audio (Opus, MP3, HE-AAC).
class VideoToAudioTab extends StatefulWidget {
  final VoidCallback? onStateChanged;

  const VideoToAudioTab({super.key, this.onStateChanged});

  @override
  State<VideoToAudioTab> createState() => VideoToAudioTabState();
}

class VideoToAudioTabState extends State<VideoToAudioTab>
    with AutomaticKeepAliveClientMixin {
  final List<MediaFile> _files = [];
  AudioFormat _selectedFormat = AudioFormat.mp3;
  bool _isDragging = false;
  bool _isConverting = false;

  // Timing for ETA estimation.
  DateTime? _conversionStartTime;
  int _filesCompletedSoFar = 0;

  // Tracking active processes for cancellation
  final Map<String, Process> _activeProcesses = {};
  bool _cancelRequested = false;

  @override
  bool get wantKeepAlive => true;

  static const _videoExtensions = {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.flv',
  };

  // --- Public state accessors for parent ---
  bool get hasUnfinishedWork {
    return _files.any(
      (f) =>
          f.status == MediaFileStatus.pending ||
          f.status == MediaFileStatus.processing,
    );
  }

  bool get isConverting => _isConverting;

  /// True when all files have been processed (done or error) and there's at
  /// least one file.
  bool get allDone {
    if (_files.isEmpty) return false;
    return _files.every(
      (f) =>
          f.status == MediaFileStatus.done || f.status == MediaFileStatus.error,
    );
  }

  int get pendingCount =>
      _files.where((f) => f.status == MediaFileStatus.pending).length;

  double get overallProgress {
    if (_files.isEmpty) return 0;
    final done =
        _files
            .where(
              (f) =>
                  f.status == MediaFileStatus.done ||
                  f.status == MediaFileStatus.error,
            )
            .length;
    return done / _files.length;
  }

  /// Estimated time remaining as a human-readable string.
  String get estimatedTimeRemaining {
    if (_conversionStartTime == null || _filesCompletedSoFar == 0) {
      return 'Calculating...';
    }
    final elapsed = DateTime.now().difference(_conversionStartTime!);
    final avgPerFile = elapsed.inSeconds / _filesCompletedSoFar;
    final remaining =
        _files
            .where(
              (f) =>
                  f.status == MediaFileStatus.pending ||
                  f.status == MediaFileStatus.processing,
            )
            .length;
    final secsLeft = (avgPerFile * remaining).round();
    if (secsLeft < 60) return '~${secsLeft}s remaining';
    final mins = secsLeft ~/ 60;
    final secs = secsLeft % 60;
    return '~${mins}m ${secs}s remaining';
  }

  int get processingCount =>
      _files.where((f) => f.status == MediaFileStatus.processing).length;

  void _notifyParent() {
    widget.onStateChanged?.call();
  }

  // --- File management ---

  int _addFiles(List<String> paths) {
    int skipped = 0;
    setState(() {
      for (final path in paths) {
        final ext = p.extension(path).toLowerCase();
        if (_videoExtensions.contains(ext)) {
          if (!_files.any((f) => f.path == path)) {
            _files.add(MediaFile(path: path, name: p.basename(path)));
          }
        } else {
          skipped++;
        }
      }
      _files.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    });
    _notifyParent();
    return skipped;
  }

  Future<List<String>> _collectFilesFromDir(String dirPath) async {
    final dir = Directory(dirPath);
    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
    return files;
  }

  Future<void> _onDropDone(DropDoneDetails details) async {
    final directFiles = <String>[];
    final folderPaths = <String>[];

    for (final xfile in details.files) {
      final path = xfile.path;
      if (await FileSystemEntity.isDirectory(path)) {
        folderPaths.add(path);
      } else {
        directFiles.add(path);
      }
    }

    if (directFiles.isNotEmpty) {
      final skipped = _addFiles(directFiles);
      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$skipped non-video file${skipped > 1 ? 's were' : ' was'} skipped. '
              'Only video files (mp4, mkv, avi, mov, webm, flv) are accepted.',
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    if (folderPaths.isNotEmpty && mounted) {
      final allFolderFiles = <String>[];
      for (final dir in folderPaths) {
        allFolderFiles.addAll(await _collectFilesFromDir(dir));
      }

      final videoCount =
          allFolderFiles
              .where(
                (f) => _videoExtensions.contains(p.extension(f).toLowerCase()),
              )
              .length;

      if (videoCount == 0) {
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  icon: const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Colors.orange,
                  ),
                  title: const Text('No Video Files Found'),
                  content: const Text(
                    'There are no supported video files in the dropped folder(s).',
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
        return;
      }

      final action = await showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              icon: const Icon(Icons.folder_open, size: 40),
              title: const Text('Import Folder'),
              content: Text(
                videoCount == allFolderFiles.length
                    ? 'Import $videoCount video file${videoCount == 1 ? '' : 's'}'
                    : 'Found ${allFolderFiles.length} item${allFolderFiles.length == 1 ? '' : 's'} '
                        'in ${folderPaths.length == 1 ? 'this folder' : '${folderPaths.length} folders'}.\n\n'
                        'Only $videoCount of them ${videoCount == 1 ? 'is a video file' : 'are video files'}.\n\n'
                        'Would you like to import the video files',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'import'),
                  icon: const Icon(Icons.video_file),
                  label: const Text('Import Video Files'),
                ),
              ],
            ),
      );

      if (action == 'import') {
        _addFiles(allFolderFiles);
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'],
      allowMultiple: true,
    );
    if (result != null) {
      _addFiles(result.paths.whereType<String>().toList());
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    _notifyParent();
  }

  void _clearFiles() {
    setState(() {
      if (_isConverting) {
        // Only clear non-processing files
        _files.removeWhere((f) => f.status != MediaFileStatus.processing);
      } else {
        _files.clear();
      }
    });
    _notifyParent();
  }

  // --- Conversion ---

  Future<String?> _pickOutputDir() async {
    final home = Platform.environment['HOME'] ?? '';
    final downloads = p.join(home, 'Downloads');
    final defaultDir = await Directory(downloads).exists() ? downloads : home;

    // Use zenity directly because the GTK file chooser used by
    // file_picker ignores initialDirectory on Linux.
    final result = await Process.run('zenity', [
      '--file-selection',
      '--directory',
      '--title=Choose output folder',
      '--filename=$defaultDir/',
    ]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  Future<void> _cancelConversion(int index) async {
    final file = _files[index];
    final process = _activeProcesses[file.path];
    if (process == null) return;

    // Kill the process with SIGKILL to force immediate termination.
    process.kill(ProcessSignal.sigkill);
    _activeProcesses.remove(file.path);

    if (mounted) {
      setState(() {
        _files[index] = _files[index].copyWith(
          status: MediaFileStatus.pending,
          progress: 0.0,
          errorMessage: null,
        );
        _isConverting = _activeProcesses.isNotEmpty;
      });
      _notifyParent();
    }
  }

  Future<void> _cancelAllConversions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel All?'),
            content: const Text(
              'Are you sure you want to cancel all current and pending conversions?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Cancel All'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      _cancelRequested = true;
      if (mounted) {
        setState(() {
          for (final entry in _activeProcesses.entries) {
            final path = entry.key;
            final idx = _files.indexWhere((f) => f.path == path);
            if (idx != -1) {
              _files[idx] = _files[idx].copyWith(
                status: MediaFileStatus.pending,
                progress: 0.0,
                errorMessage: null,
              );
            }
            entry.value.kill(ProcessSignal.sigkill);
          }
          _activeProcesses.clear();
          _isConverting = false;
        });
        _notifyParent();
      }
    }
  }

  /// Convert a single file at the given index.
  Future<void> _convertSingle(int index) async {
    final file = _files[index];
    if (file.status != MediaFileStatus.pending) return;

    final outputDir = await _pickOutputDir();
    if (outputDir == null) return;

    setState(() {
      _isConverting = true;
      _files[index] = file.copyWith(
        status: MediaFileStatus.processing,
        progress: 0.0,
      );
    });
    _notifyParent();

    final baseName = p.basenameWithoutExtension(file.path);
    final ext = extensionForFormat(_selectedFormat);
    final outputPath = p.join(outputDir, '$baseName$ext');
    final tempPath = p.join(outputDir, '$baseName.part$ext');
    final filePath = file.path;

    try {
      final result = await FfmpegService.convertVideoToAudio(
        inputPath: file.path,
        outputPath: tempPath,
        format: _selectedFormat,
        onProcessStarted: (process) {
          if (!mounted) return;
          setState(() => _activeProcesses[filePath] = process);
        },
        onProgress: (progress, eta) {
          if (!mounted) return;
          setState(() {
            final idx = _files.indexWhere((f) => f.path == filePath);
            if (idx != -1) {
              _files[idx] = _files[idx].copyWith(progress: progress, eta: eta);
            }
          });
          _notifyParent();
        },
      );

      if (!mounted) return;

      setState(() {
        _activeProcesses.remove(filePath);
        final idx = _files.indexWhere((f) => f.path == filePath);
        if (idx != -1 && _files[idx].status == MediaFileStatus.processing) {
          if (result.exitCode == 0) {
            // Rename temp file to final output.
            try {
              File(tempPath).renameSync(outputPath);
            } catch (_) {}
            _files[idx] = _files[idx].copyWith(
              status: MediaFileStatus.done,
              progress: 1.0,
            );
            NotificationService.conversionComplete(
              fileName: _files[idx].name,
              success: true,
              outputPath: outputPath,
            );
          } else {
            // Clean up partial file.
            try {
              File(tempPath).deleteSync();
            } catch (_) {}
            _files[idx] = _files[idx].copyWith(
              status: MediaFileStatus.error,
              errorMessage: result.stderr.toString(),
            );
            NotificationService.conversionComplete(
              fileName: _files[idx].name,
              success: false,
            );
            // Show error dialog.
            if (mounted) {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      icon: const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 36,
                      ),
                      title: const Text('Conversion Failed'),
                      content: SizedBox(
                        width: 500,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File: ${_files[idx].name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  result.stderr.toString(),
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
          }
        }
      });
    } finally {
      // Clean up temp file if it still exists (e.g. on cancel).
      try {
        if (File(tempPath).existsSync()) File(tempPath).deleteSync();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _activeProcesses.remove(filePath);
          _isConverting = _activeProcesses.isNotEmpty;
        });
        _notifyParent();
      }
    }
  }

  /// Convert all pending files.
  Future<void> _convertAll() async {
    if (_files.isEmpty || _isConverting) return;

    final hasPending = _files.any((f) => f.status == MediaFileStatus.pending);
    if (!hasPending) return;

    final outputDir = await _pickOutputDir();
    if (outputDir == null) return;

    setState(() {
      _isConverting = true;
      _cancelRequested = false;
      _conversionStartTime = DateTime.now();
      _filesCompletedSoFar = 0;
    });
    _notifyParent();

    try {
      while (true) {
        if (!mounted || _cancelRequested) break;

        final i = _files.indexWhere((f) => f.status == MediaFileStatus.pending);
        if (i == -1) break;

        final file = _files[i];

        setState(() {
          _files[i] = file.copyWith(
            status: MediaFileStatus.processing,
            progress: 0.0,
          );
        });
        _notifyParent();

        final baseName = p.basenameWithoutExtension(file.path);
        final ext = extensionForFormat(_selectedFormat);
        final outputPath = p.join(outputDir, '$baseName$ext');
        final tempPath = p.join(outputDir, '$baseName.part$ext');

        final filePath = file.path;

        final result = await FfmpegService.convertVideoToAudio(
          inputPath: file.path,
          outputPath: tempPath,
          format: _selectedFormat,
          onProcessStarted: (process) {
            if (!mounted) return;
            setState(() => _activeProcesses[filePath] = process);
          },
          onProgress: (progress, eta) {
            if (!mounted) return;
            setState(() {
              final idx = _files.indexWhere((f) => f.path == filePath);
              if (idx != -1) {
                _files[idx] = _files[idx].copyWith(
                  progress: progress,
                  eta: eta,
                );
              }
            });
            _notifyParent();
          },
        );

        if (!mounted) return;
        if (_cancelRequested) {
          // Clean up temp file on cancel.
          try {
            File(tempPath).deleteSync();
          } catch (_) {}
          break;
        }

        _filesCompletedSoFar++;

        setState(() {
          _activeProcesses.remove(filePath);
          final idx = _files.indexWhere((f) => f.path == filePath);
          if (idx != -1 && _files[idx].status == MediaFileStatus.processing) {
            if (result.exitCode == 0) {
              // Rename temp file to final output.
              try {
                File(tempPath).renameSync(outputPath);
              } catch (_) {}
              _files[idx] = _files[idx].copyWith(
                status: MediaFileStatus.done,
                progress: 1.0,
              );
              NotificationService.conversionComplete(
                fileName: _files[idx].name,
                success: true,
                outputPath: outputPath,
              );
            } else {
              // Clean up partial file.
              try {
                File(tempPath).deleteSync();
              } catch (_) {}
              _files[idx] = _files[idx].copyWith(
                status: MediaFileStatus.error,
                errorMessage: result.stderr.toString(),
              );
              NotificationService.conversionComplete(
                fileName: _files[idx].name,
                success: false,
              );
              // Show error dialog.
              if (mounted) {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        icon: const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 36,
                        ),
                        title: const Text('Conversion Failed'),
                        content: SizedBox(
                          width: 500,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'File: ${_files[idx].name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    result.stderr.toString(),
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
            }
          }
        });
        _notifyParent();
      }
    } finally {
      if (mounted) {
        setState(() => _isConverting = false);
        _notifyParent();
      }
    }

    if (mounted && !_cancelRequested) {
      final doneCount =
          _files.where((f) => f.status == MediaFileStatus.done).length;
      final errorCount =
          _files.where((f) => f.status == MediaFileStatus.error).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conversion complete: $doneCount done, $errorCount errors',
          ),
          action: SnackBarAction(
            label: 'Show in Folder',
            onPressed: () {
              // Open the output directory of the last converted file.
              final lastDone = _files.lastWhere(
                (f) => f.status == MediaFileStatus.done,
                orElse: () => _files.first,
              );
              NotificationService.revealInFileManager(lastDone.path);
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return DropTarget(
      onDragDone: (details) {
        if (DefaultTabController.maybeOf(context)?.index != 0) return;
        _onDropDone(details);
      },
      onDragEntered: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 0) return;
        setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        if (DefaultTabController.maybeOf(context)?.index != 0) return;
        setState(() => _isDragging = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border:
              _isDragging
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  Icon(Icons.video_file, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Video to Audio', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  const Text('Output: '),
                  const SizedBox(width: 8),
                  DropdownButton<AudioFormat>(
                    value: _selectedFormat,
                    onChanged:
                        _isConverting
                            ? null
                            : (v) => setState(() => _selectedFormat = v!),
                    items:
                        AudioFormat.values
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(labelForFormat(f)),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Files'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed:
                        _isConverting
                            ? _cancelAllConversions
                            : (pendingCount == 0 ? null : _convertAll),
                    icon: Icon(_isConverting ? Icons.cancel : Icons.transform),
                    label: Text(_isConverting ? 'Cancel All' : 'Convert All'),
                    style:
                        _isConverting
                            ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              foregroundColor: Colors.red,
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _files.isEmpty ? null : _clearFiles,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // File list or drop prompt
              Expanded(
                child:
                    _files.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_upload_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Drag & drop video files or folders here\nor use "Add Files" button',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            return _FileListTile(
                              file: file,
                              onConvert:
                                  file.status == MediaFileStatus.pending
                                      ? () => _convertSingle(index)
                                      : null,
                              onCancel:
                                  file.status == MediaFileStatus.processing
                                      ? () => _cancelConversion(index)
                                      : null,
                              onRemove:
                                  _isConverting &&
                                          file.status ==
                                              MediaFileStatus.processing
                                      ? null
                                      : () => _removeFile(index),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual file tile with a progress bar and percentage beneath it.
/// Shows a shimmer/skeleton effect when the file is processing.
class _FileListTile extends StatefulWidget {
  final MediaFile file;
  final VoidCallback? onConvert;
  final VoidCallback? onRemove;
  final VoidCallback? onCancel;

  const _FileListTile({
    required this.file,
    this.onConvert,
    this.onRemove,
    this.onCancel,
  });

  @override
  State<_FileListTile> createState() => _FileListTileState();
}

class _FileListTileState extends State<_FileListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = widget.file;
    final isProcessing = file.status == MediaFileStatus.processing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Stack(
            children: [
              // Shimmer overlay when processing.
              if (isProcessing)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1.0 + 2.0 * _shimmerController.value,
                              0,
                            ),
                            end: Alignment(
                              -0.5 + 2.0 * _shimmerController.value,
                              0,
                            ),
                            colors: [
                              Colors.transparent,
                              theme.colorScheme.primary.withOpacity(0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ListTile(
                enabled: !isProcessing,
                leading: _statusIcon(file.status),
                title: Text(file.name, overflow: TextOverflow.ellipsis),
                subtitle:
                    file.status == MediaFileStatus.error
                        ? Text(
                          file.errorMessage ?? 'Unknown error',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                        : Text(
                          file.path,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Percentage and ETA label.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _percentageLabel(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _progressColor(),
                          ),
                        ),
                        if (isProcessing &&
                            file.eta != null &&
                            file.eta!.isNotEmpty)
                          Text(
                            file.eta!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _progressColor(),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    // Per-file convert button.
                    if (widget.onConvert != null) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: widget.onConvert,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text('Convert'),
                      ),
                    ],
                    if (widget.onCancel != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: widget.onCancel,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                    if (widget.onRemove != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Progress bar below each file.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child:
                  isProcessing
                      ? LinearProgressIndicator(
                        value: file.progress > 0 ? file.progress : null,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: Colors.blue,
                      )
                      : LinearProgressIndicator(
                        value: _progressValue(),
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: _progressColor(),
                      ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _percentageLabel() {
    switch (widget.file.status) {
      case MediaFileStatus.pending:
        return '0%';
      case MediaFileStatus.processing:
        return widget.file.progress > 0
            ? '${(widget.file.progress * 100).toStringAsFixed(1)}%'
            : '...';
      case MediaFileStatus.done:
        return '100%';
      case MediaFileStatus.error:
        return 'Error';
    }
  }

  double _progressValue() {
    switch (widget.file.status) {
      case MediaFileStatus.pending:
        return 0.0;
      case MediaFileStatus.processing:
        return widget.file.progress;
      case MediaFileStatus.done:
        return 1.0;
      case MediaFileStatus.error:
        return 1.0;
    }
  }

  Color _progressColor() {
    switch (widget.file.status) {
      case MediaFileStatus.pending:
        return Colors.grey.shade400;
      case MediaFileStatus.processing:
        return Colors.blue;
      case MediaFileStatus.done:
        return Colors.green;
      case MediaFileStatus.error:
        return Colors.red;
    }
  }

  Widget _statusIcon(MediaFileStatus status) {
    switch (status) {
      case MediaFileStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
      case MediaFileStatus.processing:
        return const Icon(Icons.sync, color: Colors.blue);
      case MediaFileStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green);
      case MediaFileStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}
